#!/usr/bin/env bash
# .devcontainer/post-start.sh
#
# Runs INSIDE the `app` container after it starts.
# Triggered by `postCreateCommand` and `postStartCommand` in devcontainer.json.
#
# Responsibilities:
#   1. Patch the mounted tess.yml overlay so base_url points at the actual
#      Codespaces forwarded URL (so URL helpers in services/jobs/mailers don't
#      throw "Missing host to link to!").
#   2. Ensure Ruby deps are satisfied (the prod image already has them, but a
#      bind-mounted Gemfile may have drifted).
#   3. Prepare the database (idempotent via rails db:prepare; runs db/seeds.rb
#      on a fresh DB → roles, default user, Elixir nodes, admin user).
#   4. Import cities (idempotent: only runs when the cities table is empty —
#      the rake task uses insert_all and the table has a unique index, so a
#      naive re-run would raise a uniqueness violation).
#   5. Precompile assets on first run (the host bind mount overlays the
#      image's precompiled assets, so we have to rebuild them at runtime).
#      Skipped on resume when a Sprockets manifest already exists — developers
#      rerun the precompile via the refresh command in the READY banner.
#   6. Best-effort Solr reindex via Sunspot.
#   7. Print a clear "ready" banner with the preview URL and refresh command.
#
# Idempotent: safe to re-run on every Codespace start.

set -euo pipefail

# We're inside the `app` container; workspace is bind-mounted at /code.
cd /code
export RAILS_ENV=production

echo "[post-start] Running inside container, RAILS_ENV=${RAILS_ENV}"

# -----------------------------------------------------------------------------
# 1. Patch base_url in the tess.preview.yml overlay (mounted at /code/config/tess.yml)
#    so URL helpers resolve to the actual Codespaces forwarded URL.
# -----------------------------------------------------------------------------
if [[ -n "${CODESPACE_NAME:-}" ]]; then
  PREVIEW_URL="https://${CODESPACE_NAME}-3000.app.github.dev"
  # Replace any "base_url: <whatever>" line with the Codespaces URL.
  # Use Ruby (always present in this image — it's the Rails app's runtime).
  # The Rails image is ruby-slim and does not ship Python; previously this
  # used python3 and failed with "python3: command not found".
  ruby - "$PREVIEW_URL" <<'RB'
preview_url = ARGV[0]
path = "/code/config/tess.yml"
text = File.read(path)
new_text = text.gsub(/base_url:\s*\S+/, "base_url: #{preview_url}")
File.write(path, new_text)
RB
  echo "[post-start]   patched base_url -> ${PREVIEW_URL}"
else
  echo "[post-start]   WARN  CODESPACE_NAME not set — base_url left as-is (URL helpers may break)"
fi

# -----------------------------------------------------------------------------
# 2. Ensure Ruby deps are satisfied (cheap when already installed).
# -----------------------------------------------------------------------------
if bundle check >/dev/null 2>&1; then
  echo "[post-start]   bundle check: OK"
else
  echo "[post-start]   bundle install (Gemfile changed since image build)..."
  bundle install
fi

# -----------------------------------------------------------------------------
# 3. Prepare the database (create + schema-load + migrate + seed).
#    rails db:prepare is idempotent on Rails 7. Runs db/seeds.rb on a fresh DB.
# -----------------------------------------------------------------------------
echo "[post-start]   rails db:prepare..."
bundle exec rails db:prepare

# -----------------------------------------------------------------------------
# 4. Import cities (idempotent: skip if the table is already populated).
#    NOTE: lib/tasks/cities.rake uses City.insert_all without on_conflict,
#    and db/migrate/20250905082806_add_unique_index_to_cities_name_and_country_code
#    adds a unique index on (name, country_code). Re-running unguarded would
#    raise ActiveRecord::RecordNotUnique mid-batch.
# -----------------------------------------------------------------------------
echo "[post-start]   city:import (if needed)..."
city_count=$(bundle exec rails runner 'print City.count' 2>/dev/null || echo "0")
if [[ "${city_count}" == "0" ]]; then
  echo "[post-start]     cities table empty -> importing from config/data/cities.json"
  bundle exec rake city:import
else
  echo "[post-start]     skipped (${city_count} cities already present)"
fi

# -----------------------------------------------------------------------------
# 5. Precompile assets — required because the host bind mount overlays the
#    image's precompiled public/assets/.
#    Skip on resume when a Sprockets manifest already exists (compile is slow,
#    60-90s, and Codespaces fires postStartCommand on every resume). Asset
#    changes still get picked up via the "refresh" command in the READY banner
#    below, which the developer runs explicitly after editing code.
# -----------------------------------------------------------------------------
shopt -s nullglob
manifest_files=(public/assets/.sprockets-manifest-*.json)
shopt -u nullglob
if (( ${#manifest_files[@]} > 0 )); then
  echo "[post-start]   assets:precompile skipped (manifest present: ${manifest_files[0]##*/})"
  echo "[post-start]     if you edited app/assets, rerun: bundle exec rake assets:precompile"
else
  echo "[post-start]   rake assets:precompile (first run, ~60-90s)..."
  bundle exec rake assets:precompile
fi

# -----------------------------------------------------------------------------
# 6. Best-effort Solr reindex (Sunspot powers most browse/search flows).
#    Solr may still be warming up, so don't fail boot on this.
# -----------------------------------------------------------------------------
echo "[post-start]   rake sunspot:reindex (best-effort)..."
if bundle exec rake sunspot:reindex 2>&1; then
  echo "[post-start]   sunspot:reindex: OK"
else
  echo "[post-start]   sunspot:reindex: failed (Solr may still be starting) — continuing"
fi

# -----------------------------------------------------------------------------
# 7. Ready banner.
# -----------------------------------------------------------------------------
PREVIEW_HOST="${CODESPACE_NAME:-<codespace-name>}"
if [[ -n "${CODESPACE_NAME:-}" ]]; then
  LOCAL_SIM_BANNER=""
else
  LOCAL_SIM_BANNER="
NOTE — you are running the LOCAL Docker simulation (not an actual Codespace).
Browsing http://localhost:3000 will work for GETs, but POSTs (login, cookie
consent banner, form submissions) will return HTTP 422. This is NOT a bug in
the preview env — it is config/initializers/session_store.rb setting
secure: true on the session cookie in production mode, which browsers refuse
to store over plain HTTP. The real Codespaces URL is HTTPS, so this works
there. To verify POST flows, push the branch and open it in an actual
Codespace.
"
fi

cat <<EOF

============================================================================
TeSS preview environment (production-replica) is READY.
============================================================================

  RAILS_ENV          : production
  Rails (local)      : http://localhost:3000
  Preview URL        : https://${PREVIEW_HOST}-3000.app.github.dev
  MailHog UI         : https://${PREVIEW_HOST}-8025.app.github.dev

To SHARE the preview URL externally:
  Codespaces "Ports" tab -> right-click 3000 -> "Port Visibility" -> Public

After editing code in this Codespace, REFRESH the running app with:
  docker compose -f docker-compose-prod.yml \\
                 -f .devcontainer/docker-compose.codespaces.yml \\
                 restart app sidekiq
  docker compose -f docker-compose-prod.yml \\
                 -f .devcontainer/docker-compose.codespaces.yml \\
                 exec app bundle exec rake assets:precompile
(Class reloading is OFF in production mode — that restart is required.)

Triggered emails are captured at the MailHog UI above (nothing leaves the Codespace).
${LOCAL_SIM_BANNER}
============================================================================
EOF
