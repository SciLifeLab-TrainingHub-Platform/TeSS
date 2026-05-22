#!/usr/bin/env bash
# .devcontainer/pre-build.sh
#
# Runs on the HOST VM (Codespace VM) BEFORE docker compose starts.
# Triggered by `initializeCommand` in .devcontainer/devcontainer.json.
#
# Responsibilities:
#   1. Bootstrap gitignored config files from their *.example counterparts
#      so the bind mounts in docker-compose-prod.yml have something to mount.
#      The tracked config/tess.yml is NEVER touched here.
#   2. Generate preview-only overlays for tess.yml and secrets.yml inside
#      .devcontainer/. These are mounted OVER the tracked/bootstrapped
#      originals by .devcontainer/docker-compose.codespaces.yml so the
#      working tree stays clean.
#      - tess.preview.yml flips mailer.delivery_method to "smtp"
#      - secrets.preview.yml appends a production.smtp block pointing at
#        the MailHog sidecar.
#
# Idempotent: safe to re-run on every Codespace start.

set -euo pipefail

# Resolve repo root regardless of where the script is invoked from.
cd "$(dirname "$0")/.."

echo "[pre-build] Running in $(pwd)"

# -----------------------------------------------------------------------------
# 1. Bootstrap gitignored config files (do NOT overwrite if they already exist).
#    config/tess.yml is tracked in the repo — leave it alone.
# -----------------------------------------------------------------------------
copy_if_missing() {
  local src="$1"
  local dst="$2"
  if [[ -f "$dst" ]]; then
    echo "[pre-build]   keep   $dst (already present)"
  elif [[ -f "$src" ]]; then
    cp "$src" "$dst"
    echo "[pre-build]   create $dst (from $src)"
  else
    echo "[pre-build]   WARN   $src missing — cannot bootstrap $dst"
  fi
}

copy_if_missing env.sample                   .env
copy_if_missing config/secrets.example.yml   config/secrets.yml
copy_if_missing config/sunspot.example.yml   config/sunspot.yml
copy_if_missing config/ingestion.example.yml config/ingestion.yml

# -----------------------------------------------------------------------------
# 2. Generate preview overlays inside .devcontainer/ (gitignored).
# -----------------------------------------------------------------------------

# 2a. tess.preview.yml — copy the tracked config/tess.yml and flip the mailer
#     delivery method to "smtp" so production.rb wires Action Mailer to SMTP
#     (which we then point at MailHog via secrets.preview.yml). The tracked
#     config/tess.yml is NOT modified.
if [[ -f config/tess.yml ]]; then
  cp config/tess.yml .devcontainer/tess.preview.yml
  # Replace any "delivery_method: <whatever>" with "delivery_method: smtp".
  # Uses Python (always present in Codespaces) for safe in-place edit on macOS+Linux.
  python3 - <<'PY'
import re
import pathlib
path = pathlib.Path(".devcontainer/tess.preview.yml")
text = path.read_text()
new_text = re.sub(r"delivery_method:\s*\S+", "delivery_method: smtp", text)
path.write_text(new_text)
PY
  echo "[pre-build]   create .devcontainer/tess.preview.yml (mailer.delivery_method=smtp)"
else
  echo "[pre-build]   ERROR  config/tess.yml not found — cannot build tess.preview.yml"
  exit 1
fi

# 2b. secrets.preview.yml — copy the bootstrapped config/secrets.yml and replace
#     the production.smtp subsection IN PLACE so it talks to the MailHog sidecar.
#
#     IMPORTANT: do NOT just append another `production:` block — YAML would
#     treat the later one as a full override of the first (losing the
#     `<<: *external_api_keys` merge, secret_key_base, etc.), which then breaks
#     initializers like config/initializers/recaptcha.rb at boot.
if [[ -f config/secrets.yml ]]; then
  cp config/secrets.yml .devcontainer/secrets.preview.yml
  # Use Python with stdlib re to do a surgical, in-place edit on the production
  # block's smtp section only. We split the document at "production:" so we
  # never accidentally touch the development or test smtp blocks.
  python3 - <<'PY'
import pathlib
import re
import sys

path = pathlib.Path(".devcontainer/secrets.preview.yml")
text = path.read_text()

if "production:" not in text:
    sys.stderr.write("ERROR: 'production:' section not found in secrets.preview.yml\n")
    sys.exit(1)

# Split once at the first "production:" — everything after is fair game.
head, _, tail = text.partition("production:")

# Match the existing smtp block under production. Matches both ERB-templated
# values (the default from secrets.example.yml) and any prior overrides.
smtp_re = re.compile(
    r"""
    (\n[ \t]+)smtp:\s*\n
    (?:[ \t]+:?address:.*\n)?
    (?:[ \t]+:?port:.*\n)?
    (?:[ \t]+:?domain:.*\n)?
    (?:[ \t]+:?enable_starttls_auto:.*\n)?
    (?:[ \t]+:?authentication:.*\n)?
    (?:[ \t]+:?user_name:.*\n)?
    (?:[ \t]+:?password:.*\n)?
    """,
    re.VERBOSE,
)

# Replacement preserves the original indentation of the `smtp:` key (captured
# in group 1, which is "\n<spaces>"). We strip the leading newline so we
# don't end up with blank lines between every value.
def replace(match):
    indent_spaces = match.group(1).lstrip("\n")
    inner = indent_spaces + "  "
    return (
        f"\n{indent_spaces}smtp:\n"
        f"{inner}address: mailhog\n"
        f"{inner}port: 1025\n"
        f"{inner}domain: preview.local\n"
        f"{inner}enable_starttls_auto: false\n"
    )

new_tail, n = smtp_re.subn(replace, tail, count=1)
if n != 1:
    sys.stderr.write(
        "ERROR: could not locate the production.smtp block to override. "
        "config/secrets.example.yml may have drifted; update pre-build.sh.\n"
    )
    sys.exit(1)

path.write_text(head + "production:" + new_tail)
PY
  echo "[pre-build]   create .devcontainer/secrets.preview.yml (production.smtp -> mailhog:1025, in-place)"
else
  echo "[pre-build]   ERROR  config/secrets.yml not found — cannot build secrets.preview.yml"
  exit 1
fi

echo "[pre-build] Done."
