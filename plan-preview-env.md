# Plan: GitHub Codespaces PR Preview Environments for TeSS (Production-Replica Mode)

## Goal

Set up **GitHub Codespaces** as a lightweight, on-demand PR preview environment for this Rails application (SciLifeLab Training Hub Portal, fork of TeSS).

> **Important change from earlier draft:** the preview environment must be a **replica of the production stack**, not the development stack. We use `docker-compose-prod.yml` (`Dockerfile` `production` target, `RAILS_ENV=production`, precompiled assets, static file serving) as the base. See [Tradeoffs of Production-Replica Mode](#tradeoffs-of-production-replica-mode) for what this costs us.

### Hard constraints

- This repo contains ONLY application code (no k8s manifests, no Helm charts).
- Preview environments MUST NOT depend on Kubernetes, kind, k3s, Helm, ArgoCD, Cloudflare Tunnel, paid services, or any external infrastructure.
- Preview environments MUST run entirely inside GitHub Codespaces using Docker Compose.
- Preview environments MUST reflect the PR branch source — every Codespace is created from the PR branch, so the image is built from the latest PR code at boot.
- The existing GitHub Actions image-build pipelines (`.github/workflows/build.yaml` and friends) must remain UNTOUCHED.

### Reviewer journey we want to enable

1. Open / view a PR.
2. Launch a Codespace from the PR branch ("Code" → "Codespaces" → "Create codespace on this branch").
3. Codespace builds the **production image** from PR source and boots the full prod-style stack via Docker Compose.
4. Rails (in `production` mode) is reachable via the auto-forwarded Codespaces URL on port `3000`.
5. Reviewer changes the `3000` port visibility to **Public** in the "Ports" tab to share the preview URL.
6. Any further code changes pushed to the PR are picked up by either (a) rebuilding the Codespace, or (b) `docker compose build app && docker compose up -d app` inside the Codespace.

---

## High-Level Architecture

```text
GitHub PR
    ↓
"Create codespace on this branch"
    ↓
Codespace boots devcontainer
    ↓
docker-compose-prod.yml + .devcontainer/docker-compose.codespaces.yml
    ↓
app (Rails, RAILS_ENV=production, assets precompiled)
+ db (Postgres) + solr (Solr 8) + redis + sidekiq
    ↓
Rails bound to 0.0.0.0:3000, serves static assets
    ↓
Forwarded as https://<codespace>-3000.app.github.dev
    ↓
Reviewer marks port 3000 Public → shares URL
```

---

## How GitHub Codespaces and `.devcontainer/` Work (Background)

For maintainers / future contributors. Skip if you already know the Dev Containers spec.

### Mental model in 60 seconds

A **Codespace** is a remote Linux VM that GitHub spins up on demand, with the PR branch already checked out and a development environment ready. Reviewers access it through their browser (or VS Code desktop). The reviewer's laptop is just a thin client — everything runs on GitHub's infrastructure.

The **`.devcontainer/` folder** is how the repo *tells* Codespaces what kind of environment to set up. It implements the open [Dev Containers spec](https://containers.dev) (originally a VS Code feature; Codespaces uses the same spec). If a repo has a `.devcontainer/`, Codespaces follows it; otherwise it falls back to a generic universal image.

### Files in our `.devcontainer/`

```text
.devcontainer/
├── devcontainer.json              ← THE config: which image/compose, which ports, what to run after start
├── docker-compose.codespaces.yml  ← compose override layered on top of docker-compose-prod.yml
├── pre-build.sh                   ← runs on the HOST before the container starts
├── post-start.sh                  ← runs INSIDE the container after it starts
├── .gitignore                     ← keeps generated overlay files out of git
├── tess.preview.yml               ← (generated, gitignored) overlay for config/tess.yml
└── secrets.preview.yml            ← (generated, gitignored) overlay for config/secrets.yml
```

### Boot sequence, step by step

When a reviewer clicks **Code → Codespaces → Create codespace on this branch**:

1. **VM provisioned**: GitHub allocates a Linux VM (default: 2-core / 8 GB RAM / 32 GB disk).
2. **Repo checked out**: the PR branch is cloned into `/workspaces/TeSS` on the VM.
3. **`devcontainer.json` is read**: Codespaces sees `dockerComposeFile: ["../docker-compose-prod.yml", "docker-compose.codespaces.yml"]` and knows to use Compose.
4. **`initializeCommand` runs on the HOST VM**: our `pre-build.sh`. Copies `env.sample → .env`, bootstraps gitignored config files, and generates the two `.preview.yml` overlays.
5. **`docker compose up` runs**: Compose merges the base (`docker-compose-prod.yml`) and the override (`docker-compose.codespaces.yml`) into a final spec. Images get built (first time: ~5–10 min for the `production` Dockerfile target).
6. **Containers start**: `app`, `db`, `solr`, `redis`, `sidekiq`, `mailhog`. The `app` container is the "primary" one Codespaces attaches to.
7. **`postCreateCommand` runs INSIDE the `app` container**: our `post-start.sh`. Patches `base_url` to the Codespaces URL, runs `bundle check`, `db:prepare`, `assets:precompile`, best-effort `sunspot:reindex`.
8. **Codespace is ready**: VS Code editor opens in the browser, connected to the `app` container.
9. **Ports auto-forwarded**: `3000` (Rails) and `8025` (MailHog) get HTTPS tunnels on the `app.github.dev` domain.
10. **Visibility default = Private**: only the logged-in reviewer can access the URLs. To share externally, they manually change `3000` to **Public** in the Ports tab.

### How port forwarding works (the "magic" public URL)

Codespaces runs an internal proxy that:

- Watches for processes binding to ports inside the container.
- For any port in `forwardPorts` (or auto-detected), creates a public HTTPS URL on `*.app.github.dev`.
- That URL is gated by GitHub auth by default (Private). When set to Public, anyone with the URL can hit it — still terminated at GitHub's edge with valid TLS.

This is why we get a real `https://...` URL with no DNS, no Cloudflare, no ngrok, no ingress — GitHub provides the tunnel as part of Codespaces.

### How "live PR changes" actually work

Because `.devcontainer/docker-compose.codespaces.yml` bind-mounts `.:/code`, the running container sees the same files the editor sees. So:

- Edit a file in VS Code → instantly visible inside the container.
- BUT production mode does NOT auto-reload → must `docker compose restart app sidekiq`.
- For asset changes → also `rake assets:precompile`.

For a brand-new commit pushed by someone else: `git pull` inside the Codespace terminal, then the same restart.

### Lifecycle & cost

- **Auto-stop** after 30 min of inactivity (configurable).
- **Auto-delete** after 30 days of inactivity (configurable).
- **Free quota**: GitHub gives free Codespaces hours per user (currently 120 core-hours/month on a 2-core machine for free accounts; more for paid/org plans).
- **Stopped Codespaces** still consume *storage* quota but no compute.
- **Per-user isolation**: each reviewer gets their own VM. No shared state between reviewers.

### Same `.devcontainer/` works locally too

The Dev Containers spec is open and supported by:

- GitHub Codespaces (cloud).
- VS Code desktop with the "Dev Containers" extension (local Docker).
- JetBrains Gateway.

So anyone with Docker can run the same preview locally by opening the repo in VS Code and clicking "Reopen in Container".

### Quick reference table

| Concept | What it is |
| --- | --- |
| Codespace | A remote VM with your repo + dev env, accessed via browser |
| `.devcontainer/devcontainer.json` | The contract: image, services, ports, post-start commands |
| `.devcontainer/docker-compose.codespaces.yml` | A Compose override layered on top of the prod compose file |
| `pre-build.sh` | Runs on the host VM before containers start — bootstraps configs |
| `post-start.sh` | Runs inside the container after start — prepares DB, assets, etc. |
| `forwardPorts` | Tells Codespaces which ports to tunnel publicly via `app.github.dev` |
| Port visibility | Private by default; reviewer flips to Public to share |
| Bind mount `.:/code` | Source code stays in sync between editor and container |

---

## Repository Facts (from `CLAUDE.md`)

These determine the concrete choices below:

- **Runtime**: Ruby `3.2.5`, Rails `7.0.8.4`.
- **Required services**: Postgres 14, Solr 8 (Sunspot — most flows break without it), Redis 6, Sidekiq.
- **Existing compose files**:
  - `docker-compose.yml` → dev stack, `target: development`, bind-mounts `.:/code`. Source live-reloads.
  - `docker-compose-prod.yml` → **prod stack, `target: production`, assets precompiled at image build, no source bind mount, mounts only `config/tess.yml` and `config/secrets.yml`, `RAILS_ENV=production`, `RAILS_SERVE_STATIC_FILES=true`, includes `dbbackups`.** **This is our base.**
- **Dockerfile** (multi-stage: `base`, `development`, `production`):
  - `production` target: `bundle install` → `COPY . .` → `rake assets:precompile` → CMD runs `whenever` → `supercronic` → `rails server -b 0.0.0.0`.
- **App service name** in compose: `app`.
- **Entrypoint**: `docker/entrypoint.sh` (just clears stale `server.pid`).
- **Asset pipeline**: Sprockets only (no Vite/Webpacker → no `yarn install` needed at boot).
- **Config file layout** (verified against `.gitignore`):
  - `config/tess.yml` is **tracked in the repo** — Codespaces gets it directly from the PR branch; we DO NOT copy from `tess.example.yml`. We only patch `base_url` at preview-time so URL helpers resolve to the Codespaces forwarded URL.
  - The following ARE gitignored and must be bootstrapped from examples on first boot:
    - `config/secrets.yml` ← `config/secrets.example.yml`
    - `config/sunspot.yml` ← `config/sunspot.example.yml`
    - `config/ingestion.yml` ← `config/ingestion.example.yml`
    - `.env` ← `env.sample`
- **Critical env vars in production mode**:
  - `RAILS_DEVELOPMENT_HOSTS` is **ignored** when `RAILS_ENV=production`. Host allowlisting in production is governed by `config.hosts` in `config/environments/production.rb`. By default that array is **empty**, which means **all hosts are accepted** (no Host Authorization check). Codespaces forwarded URLs therefore work out of the box.
  - `TeSS::Config.base_url` (from `config/tess.yml`) — drives URL helpers, mailer links, Slack message URLs. MUST point to the Codespaces forwarded URL so generated URLs are click-able.
  - `SECRET_KEY_BASE` — required in production. We generate a throwaway one in `post-start.sh`.
- **Branching** (source of truth: `.github/workflows/build.yaml`, not `README.md`):
  - Working branches are `rc-*`. **Currently active**: `rc-1.6.0`. PRs target these.
  - Feature branches are short-lived, named `feat/<short-description>` (e.g. `feat/codespaces-preview`), opened against the active `rc-*` branch.
  - `master` is a read-only mirror of upstream `ElixirTeSS/TeSS` — never push to it.
  - `develop` is NOT used by the current workflows; ignore the outdated mention in `README.md`.

---

## Compose Strategy Decision

We will **reuse the existing `docker-compose-prod.yml`** as the base and layer a Codespaces-specific override.

Why `docker-compose-prod.yml`:

- Matches production semantics: same image target, same env, same asset serving model, same Sidekiq command, same cron supervisor (`supercronic`).
- Reviewers see exactly what a prod deploy would render (asset digests, no dev error pages, real `production.rb` middleware stack).

What the Codespaces override file (`.devcontainer/docker-compose.codespaces.yml`) MUST do:

1. **Source visibility for PR changes** — add a bind mount of the PR workspace into `/code` on the `app` and `sidekiq` services so the image always reflects the PR branch (even after rebuilds within the Codespace). This is a deliberate divergence from real prod (which is fully immutable); see [Tradeoffs](#tradeoffs-of-production-replica-mode).
2. **Force a runtime `assets:precompile`** after the mount, because mounting the host source over `/code` hides the assets baked into the production image. We do this in `post-start.sh`, not at build time.
3. **Bootstrap missing prod-required config files** (`config/tess.yml`, `config/secrets.yml`). The prod compose **bind-mounts these from the host** — if they don’t exist on the host the container will fail to start. `post-start.sh` creates them from `*.example.yml` before `docker compose up`.
4. **Disable `dbbackups`** in the preview environment (not useful, just consumes resources).
5. **Set `SECRET_KEY_BASE`** to a throwaway value via env so the production Rails boot does not crash.
6. **Generate `.env`** from `env.sample` if missing (compose uses `${PREFIX}`, `${DB_*}` etc.).

What we do NOT change:

- `Dockerfile` (use the existing `production` target unchanged).
- `docker-compose.yml` / `docker-compose-prod.yml` (untouched).
- Any file under `.github/workflows/`.

---

## Tradeoffs of Production-Replica Mode

Reviewer should be aware of these BEFORE we implement:

| Aspect | Dev replica (previous plan) | Prod replica (this plan) |
| --- | --- | --- |
| Cold start | Fast (≈1–3 min) | Slow (≈5–10 min — full `bundle install` + `assets:precompile` at image build) |
| Live code reload | Yes (Rails auto-reload) | **No** — production mode does not reload classes. After a code edit you must `docker compose restart app sidekiq`. |
| Error pages | Full dev backtraces | Generic production error pages (closer to real UX) |
| Asset behaviour | Sprockets dev mode | Precompiled, fingerprinted, served by Rails (`RAILS_SERVE_STATIC_FILES=true`) |
| Realism | Lower | **Higher — matches the deployed app** |
| Resource use in Codespace | Lower | Higher (precompiled assets, more memory) |

**Mitigations** included in the plan:

- We bind-mount the PR source so a rebuild of just the `app` container (`docker compose build app && docker compose up -d app`) is enough to pick up edits — no Codespace rebuild needed.
- `post-start.sh` runs `assets:precompile` after the mount so the served assets reflect the PR.
- We expose a small helper command (`bin/preview-refresh` in the plan, optional) that wraps the rebuild + asset recompile + restart for reviewers.

---

## Deliverables

### 1. `.devcontainer/devcontainer.json`

Responsibilities:

- Tell Codespaces this project uses Docker Compose.
- Reference BOTH the base `docker-compose-prod.yml` and the new `docker-compose.codespaces.yml` override (override wins).
- Attach to the `app` service.
- `workspaceFolder: /code` (matches what the prod image expects).
- Auto-forward port `3000` with a friendly label.
- Run `bash .devcontainer/post-start.sh` on `postCreateCommand` and `postStartCommand` (both — idempotent).
- Install a small set of useful VS Code extensions.

Proposed shape (for the implementing agent to render as JSON):

- `name`: `"TeSS PR Preview (prod-replica)"`
- `dockerComposeFile`: `["../docker-compose-prod.yml", "docker-compose.codespaces.yml"]`
- `service`: `"app"`
- `workspaceFolder`: `"/code"`
- `forwardPorts`: `[3000, 8025]` (3000 = Rails, 8025 = MailHog UI for captured email)
- `portsAttributes`:
  - `"3000"`: `{ "label": "Rails (TeSS, production)", "onAutoForward": "notify" }`
  - `"8025"`: `{ "label": "MailHog (captured email)", "onAutoForward": "openPreview" }`
- `otherPortsAttributes`: `{ "onAutoForward": "ignore" }` (keep Postgres/Redis/Solr/SMTP private)
- `initializeCommand`: `"bash .devcontainer/pre-build.sh"` (runs on the HOST before the container starts — used to copy example config files so the bind mounts in `docker-compose-prod.yml` find them. See deliverable #4.)
- `postCreateCommand`: `"bash .devcontainer/post-start.sh"`
- `postStartCommand`: `"bash .devcontainer/post-start.sh"`
- `remoteUser`: `"root"` (the `Dockerfile` `production` target runs as root)
- `customizations.vscode.extensions`:
  - `Shopify.ruby-lsp`
  - `castwide.solargraph`
  - `ms-azuretools.vscode-docker`
  - `redhat.vscode-yaml`

### 2. `.devcontainer/docker-compose.codespaces.yml`

A minimal override on top of `docker-compose-prod.yml`. It must NOT duplicate the whole stack.

Required overrides on the `app` service:

- `volumes`: ADD
  - `.:/code` (PR source visibility)
  - `./.devcontainer/tess.preview.yml:/code/config/tess.yml:ro` (overlay so we don’t mutate the tracked `config/tess.yml`; required for redirecting mail to MailHog)
  - `./.devcontainer/secrets.preview.yml:/code/config/secrets.yml:ro` (overlay holding MailHog SMTP settings)
- `environment`:
  - `SECRET_KEY_BASE: "preview-codespace-secret-not-for-production"`
  - `RAILS_LOG_TO_STDOUT: "true"` (already true in base, kept for clarity)
  - `RAILS_SERVE_STATIC_FILES: "true"` (already true in base, kept for clarity)
  - `SLACK_BOT_USER_OAUTH_TOKEN: ${SLACK_BOT_USER_OAUTH_TOKEN:-}` (passthrough from a Codespaces Secret — empty by default → Slack job logs an error and moves on, safe)
  - `SLACK_COURSE_NOTIFICATION_CHANNELS: ${SLACK_COURSE_NOTIFICATION_CHANNELS:-#tess-preview-test}` (defaults to a placeholder channel; overridable per-user via Codespaces Secret)
- `depends_on`: ADD `mailhog`
- `restart: "no"` (override base `restart: always` — easier to debug during reviews)
- `tty: true`, `stdin_open: true`

Required overrides on the `sidekiq` service:

- `volumes`: ADD `.:/code`, plus the same two overlay mounts as `app`.
- `environment`: same `SECRET_KEY_BASE`, `SLACK_BOT_USER_OAUTH_TOKEN`, and `SLACK_COURSE_NOTIFICATION_CHANNELS` passthroughs as `app` (Sidekiq is the process that actually runs `SlackNotificationJob`).
- `depends_on`: ADD `mailhog`.
- `restart: "no"`.

Required new service in the override (NOT in the base file):

- `mailhog`:
  - `image: mailhog/mailhog:latest`
  - `ports: ["8025:8025"]` (only the UI is exposed; SMTP `1025` stays internal)
  - `restart: "no"`

Required override on `dbbackups`:

- `profiles: ["disabled"]` — keeps it from starting in the preview (Compose v2 honours profiles in overrides).

Nothing else needs to change — `db`, `solr`, `redis` from `docker-compose-prod.yml` work as-is.

> Why no `RAILS_DEVELOPMENT_HOSTS`? In production mode Rails ignores it. `config/environments/production.rb` in this repo does not populate `config.hosts`, so Host Authorization accepts every host by default — Codespaces forwarded hostnames work without any allowlisting. Documented explicitly so we don’t add dead env vars.

### 3. `.devcontainer/pre-build.sh` (NEW — runs on the host before container start)

Needed because `docker-compose-prod.yml` mounts `./config/tess.yml` and `./config/secrets.yml` from the host. If those files don’t exist on the host, the container fails to start. This script bootstraps them BEFORE compose runs.

```bash
#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

# 1. Bootstrap gitignored config files from their examples (idempotent).
#    config/tess.yml is tracked in the repo — DO NOT touch it directly.
[[ -f .env ]]                 || cp env.sample                  .env
[[ -f config/secrets.yml ]]   || cp config/secrets.example.yml  config/secrets.yml
[[ -f config/sunspot.yml ]]   || cp config/sunspot.example.yml  config/sunspot.yml
[[ -f config/ingestion.yml ]] || cp config/ingestion.example.yml config/ingestion.yml

# 2. Generate preview-only overlays for tess.yml and secrets.yml.
#    These are mounted OVER the tracked/bootstrapped originals by the
#    Codespaces compose override, so the working tree stays clean.
cp config/tess.yml .devcontainer/tess.preview.yml
# Force mailer.delivery_method to "smtp" in the overlay so production.rb wires
# Action Mailer to SMTP -> MailHog. Original tess.yml is NOT modified.
python3 - <<'PY'
import re, pathlib
p = pathlib.Path(".devcontainer/tess.preview.yml")
t = p.read_text()
t = re.sub(r"delivery_method:\s*\S+", "delivery_method: smtp", t)
p.write_text(t)
PY

cp config/secrets.yml .devcontainer/secrets.preview.yml
cat >> .devcontainer/secrets.preview.yml <<'YML'

# ---- injected by .devcontainer/pre-build.sh for Codespaces preview ----
production:
  smtp:
    address: mailhog
    port: 1025
    domain: preview.local
    enable_starttls_auto: false
YML

echo "[pre-build] Bootstrapped config + generated preview overlays for tess.yml / secrets.yml."
```

### 4. `.devcontainer/post-start.sh`

Runs **inside** the `app` container after it starts. Idempotent. Must `set -euo pipefail` and be `chmod +x`.

Pseudocode:

```bash
#!/usr/bin/env bash
set -euo pipefail

cd /code
export RAILS_ENV=production

# 1. Point Rails URL helpers at the Codespaces forwarded URL.
if [[ -n "${CODESPACE_NAME:-}" ]]; then
  PREVIEW_URL="https://${CODESPACE_NAME}-3000.app.github.dev"
  # Only rewrite if the file still has the localhost default.
  sed -i "s|base_url: http://localhost:3000|base_url: ${PREVIEW_URL}|g" config/tess.yml || true
fi

# 2. Ruby deps are already installed in the prod image, but the bind mount
#    may have introduced new gems. `bundle check` is cheap; `bundle install`
#    only runs when needed.
bundle check >/dev/null 2>&1 || bundle install

# 3. Database: create + schema-load + migrate + seed (idempotent on Rails 7).
bundle exec rails db:prepare

# 4. Precompile assets AFTER the host bind mount overlays the image's /code.
#    Without this, mounted source hides image-baked assets and Sprockets 404s.
bundle exec rake assets:precompile

# 5. Best-effort Solr reindex (Sunspot powers most browse/search flows).
bundle exec rake sunspot:reindex || true

# 6. Hint for the reviewer.
cat <<EOF

TeSS preview environment (production-replica) is ready.

  - RAILS_ENV:    production
  - Rails:        http://localhost:3000 (forwarded)
  - Preview URL:  https://${CODESPACE_NAME:-<codespace>}-3000.app.github.dev
  - To share:     "Ports" tab → right-click 3000 → "Port Visibility" → Public

After editing code in the PR, run:
  docker compose -f docker-compose-prod.yml -f .devcontainer/docker-compose.codespaces.yml \\
    restart app sidekiq && \\
  docker compose -f docker-compose-prod.yml -f .devcontainer/docker-compose.codespaces.yml \\
    exec app bash -lc "bundle exec rake assets:precompile"

(Class reloading is OFF in production mode — that restart is required.)

EOF
```

Notes:

- `rails db:prepare` is safe to run repeatedly.
- `assets:precompile` is required because the host bind mount overlays the image’s precompiled assets.
- `sunspot:reindex` is best-effort — Solr may still be warming up.
- `SECRET_KEY_BASE` comes from the compose override, not the script.

### 5. Dockerfile adjustments

None required. The existing `production` target is reused as-is. We deliberately do not modify `Dockerfile`, `docker-compose.yml`, or `docker-compose-prod.yml`.

### 6. Optional helper: `bin/preview-refresh`

A tiny convenience script for reviewers to refresh the preview after code changes (wraps the long `docker compose` command from `post-start.sh`). Optional for v1 — not strictly needed.

---

## Port & Visibility Plan

- `forwardPorts: [3000]` → Codespaces auto-forwards Rails.
- `portsAttributes` labels it "Rails (TeSS, production)" and notifies on first open.
- `otherPortsAttributes.onAutoForward = "ignore"` keeps Postgres `5432`, Redis `6379`, Solr `8983` from being forwarded (they’re only reachable on the internal Docker network anyway).
- Reviewer manually marks `3000` as **Public** in the Ports tab to share externally. This is documented in the `post-start.sh` output.

---

## Security Considerations

### Baseline (zero secrets)

By default the preview environment ships **no real credentials**:

- Configs come from `*.example.yml` and `env.sample` (or the tracked `config/tess.yml`, which itself contains only placeholders).
- `SECRET_KEY_BASE` is a static throwaway value set via the compose override.
- DB / Redis / Solr ports are not forwarded.
- The seeded admin user is the placeholder from `env.sample` (`admin_user` / `changeme!`).
- Production `config.hosts` is empty → Host Authorization accepts the Codespaces hostname without changes.
- Nothing under `.devcontainer/` contains real hostnames, tokens, or production URLs.

### Is Codespaces secure enough for testing with real secrets?

Short answer: **yes, but only if you use the right delivery mechanism and the right "test" secrets — never real prod ones.**

How Codespaces handles secrets:

- GitHub provides **Codespaces Secrets** — encrypted, injected as env vars at start, never written to the repo, never echoed by GitHub.
- Configured at:
  - **User level** → `https://github.com/settings/codespaces` (visible only to your own Codespaces)
  - **Org level** → org settings → *Codespaces* → *Secrets* (scoped to selected repos; org owners only)
- They override anything in `.env` and are available to processes via standard `ENV[...]` access.
- They are NOT visible to other reviewers’ Codespaces unless you explicitly share them at the org level.

What Codespaces does NOT protect you from:

- **Public forwarded ports.** When you flip port `3000` to **Public**, anyone with the URL (no auth) can hit any endpoint — including ones that trigger Slack posts or emails. With real tokens loaded, that means real side effects.
- **Anything you `echo` in scripts.** `set -x`, accidental `puts ENV['...']`, or unfiltered exception traces can leak a token into logs visible in the Codespace UI.
- **Sandbox escape via your own code.** Codespaces is a remote dev VM; treat it as untrusted for storing long-lived production secrets.

### Recommended pattern for testing notifications/email

Use **test endpoints / test workspaces**, delivered via **Codespaces Secrets**:

| What you want to test | Real prod token? | Recommended |
| --- | --- | --- |
| Slack notifications | ❌ never | Create a separate test Slack workspace + a dedicated bot, store its token as a Codespaces Secret (e.g. `SLACK_BOT_USER_OAUTH_TOKEN`), point `SLACK_COURSE_NOTIFICATION_CHANNELS` at a test channel only. |
| Outgoing email (SMTP) | ❌ never | Use **Mailtrap.io** (free tier) or **mailcatcher**/**MailHog** as a sidecar in `docker-compose.codespaces.yml`. Point `secrets.smtp.*` at it. No real SMTP creds in the Codespace. |
| OIDC (LS-Login) | ❌ never | Stick to Devise database auth for previews. Real OIDC is out of scope. |

Concrete safeguards we will bake into the preview:

1. **Bootstrapped `config/secrets.yml` ships with NO Slack token.** `SlackNotificationJob` calls `Slack::Web::Client.new` which reads `SLACK_API_TOKEN` / `SLACK_BOT_USER_OAUTH_TOKEN` from the env. If neither is set, the call fails fast in the rescue block (`Slack::Web::Api::Errors::SlackError`) and the job logs an error instead of posting. So the default preview is non-posting.
2. **Keep port `3000` Private while you have real tokens loaded.** Make it Public only when (a) you are using throwaway test tokens AND (b) you actively need to share the URL. Flip it back to Private when done.
3. **Don’t print secrets from `post-start.sh` or `pre-build.sh`** — both scripts use `set -euo pipefail` (no `-x`) and never `echo $SLACK_*` etc.
4. **Use a per-Codespace `.env` override** for ad-hoc local-only secrets if you must: add a line to your personal `.env` inside the Codespace (it’s gitignored), don’t commit it. Codespaces Secrets are still preferable.
5. **For shared previews on `rc-*` branches**, prefer org-level Codespaces Secrets so reviewers get the same controlled test endpoints without each person managing their own tokens.

### Capturing email & Slack in the preview WITHOUT any code changes

Goal: let a reviewer trigger the real app flows (event publish, password reset, etc.) and **see** the messages, **without** sending them anywhere real and **without** modifying any tracked source file (no Ruby, no tracked `config/tess.yml`).

How TeSS picks its delivery method (verified, no code change needed):

- `config/environments/production.rb` reads `TeSS::Config.mailer['delivery_method']`. If it equals `"smtp"`, it wires `config.action_mailer.delivery_method = :smtp` and pulls SMTP host/port/etc. from `Rails.application.secrets[:smtp]`.
- That `TeSS::Config.mailer` value comes from `config/tess.yml`. The `Rails.application.secrets[:smtp]` value comes from `config/secrets.yml`.
- So: to redirect mail to a capture sandbox, we only need to ship a **different `tess.yml`** (with `mailer.delivery_method: smtp`) and a **different `secrets.yml`** (with SMTP pointing at MailHog). The Ruby stays untouched.

Implementation pattern (everything stays inside `.devcontainer/`):

1. **Add a MailHog sidecar** in `.devcontainer/docker-compose.codespaces.yml`:

   ```yaml
   services:
     mailhog:
       image: mailhog/mailhog:latest
       ports:
         - "8025:8025"   # web UI
         # SMTP 1025 stays on the internal docker network only
       restart: "no"
   ```

   MailHog captures every outbound message and shows them in a web UI on port `8025`. Nothing leaves the Codespace.

2. **Generate preview-only overlay configs in `pre-build.sh`** (host-side, before compose starts):

   ```bash
   # Build a preview tess.yml from the tracked one, only changing the mailer block.
   # Output lives inside .devcontainer/ and is gitignored via the .devcontainer/.gitignore
   # we ship alongside (so it never gets committed even if a reviewer is sloppy).
   cp config/tess.yml .devcontainer/tess.preview.yml
   # naive but safe: ensure delivery_method is smtp under default + production sections
   python3 - <<'PY'
   import re, pathlib
   p = pathlib.Path(".devcontainer/tess.preview.yml")
   t = p.read_text()
   t = re.sub(r"delivery_method:\s*\S+", "delivery_method: smtp", t)
   p.write_text(t)
   PY

   # Same idea for secrets.yml — bootstrap from example, then inject mailhog SMTP block.
   [[ -f config/secrets.yml ]] || cp config/secrets.example.yml config/secrets.yml
   cp config/secrets.yml .devcontainer/secrets.preview.yml
   cat >> .devcontainer/secrets.preview.yml <<'YML'

   # ---- injected by .devcontainer/pre-build.sh for Codespaces preview ----
   production:
     smtp:
       address: mailhog
       port: 1025
       domain: preview.local
       enable_starttls_auto: false
   YML
   ```

   > Note: the `python3` snippet is just one way to do the YAML-safe edit. Bash `sed` works too; the implementing agent should pick whichever is cleanest. The important point is we **never edit the tracked `config/tess.yml` in place** — the overlay file lives under `.devcontainer/`.

3. **Mount the overlays in `.devcontainer/docker-compose.codespaces.yml`** so they win over the bind mounts coming from `docker-compose-prod.yml`:

   ```yaml
   services:
     app:
       volumes:
         - .:/code
         - ./.devcontainer/tess.preview.yml:/code/config/tess.yml:ro
         - ./.devcontainer/secrets.preview.yml:/code/config/secrets.yml:ro
       depends_on:
         - mailhog
     sidekiq:
       volumes:
         - .:/code
         - ./.devcontainer/tess.preview.yml:/code/config/tess.yml:ro
         - ./.devcontainer/secrets.preview.yml:/code/config/secrets.yml:ro
       depends_on:
         - mailhog
   ```

4. **Forward port `8025` for the MailHog UI** in `devcontainer.json`:

   ```jsonc
   "forwardPorts": [3000, 8025],
   "portsAttributes": {
     "3000": { "label": "Rails (TeSS, production)", "onAutoForward": "notify" },
     "8025": { "label": "MailHog (captured email)", "onAutoForward": "openPreview" }
   }
   ```

5. **Gitignore the generated overlays** by shipping a tiny `.devcontainer/.gitignore`:

   ```text
   tess.preview.yml
   secrets.preview.yml
   ```

   That file IS committed (so the rule travels with the repo), but the generated overlays are not.

What this gives the reviewer, with zero changes to any existing source/config file:

- Trigger any flow that sends mail in the app (event publish → user/admin/content-provider mailers, password reset, invitations, etc.).
- Open the MailHog UI at `https://<codespace>-8025.app.github.dev` and inspect every captured message — full HTML, headers, attachments.
- Nothing reaches the real internet. No SMTP credentials needed.

### What about Slack?

Slack is different — `SlackNotificationJob#perform` calls `Slack::Web::Client.new`, which requires a real token to even attempt a POST. There is no public "MailHog for Slack". Practical options, in order of preference:

- **Do nothing** (default of this plan). With no token in `secrets.yml`/env, the job logs a Slack API error and moves on. The *message body* is still constructed (which is what would expose the `Missing host to link to!` bug, for example) — so most "does the notification path work?" testing is already covered.
- **Use a test Slack workspace + dedicated test bot**, with its token injected via a Codespaces Secret (`SLACK_BOT_USER_OAUTH_TOKEN`) and `SLACK_COURSE_NOTIFICATION_CHANNELS` pointed at a throwaway channel in that workspace. Still no code change.
- (Last resort) Run a local HTTP mock that pretends to be `slack.com`. This requires either a code change or DNS/proxy trickery and is **out of scope** for this plan — we explicitly do not pursue it.

### Trust boundary summary

- **Trusted inside the Codespace**: Codespaces Secrets, anything injected via the GitHub Codespaces UI, the repo source.
- **Untrusted (do NOT put real prod data here)**: `.env`, `config/secrets.yml`, `config/tess.yml`, anything committed to the repo, anything echoed in logs.
- **Public-facing**: only the explicitly-forwarded port `3000`, only when set to Public. Treat it like an unauthenticated public URL.

---

## Interaction with Existing CI Pipelines

Untouched. The new files live under `.devcontainer/` (plus `plan-preview-env.md`). None of these match the path filters in:

- `.github/workflows/build.yaml` (PRs/pushes to `rc-*`, tag `rc-v*`, releases) — still builds dev/preprod/prod images exactly as before.
- `.github/workflows/test.yml`, `deployment-checks.yml`, `docker-*.yml`, `codeql-analysis.yml`, `pgbackup.yaml` — unchanged.

Codespaces previews are intentionally **independent** of these image pipelines.

---

## Implementation Steps (Sequenced — Execute One at a Time)

Each step below is a discrete, executable chunk. Do them in order; do not skip ahead. Each step's "Exit criteria" tells you when it is safe to move to the next.

> **Hard rule applied throughout**: do NOT modify any file under `.github/workflows/`, `Dockerfile`, `docker-compose.yml`, `docker-compose-prod.yml`, `config/tess.yml`, `app/`, `lib/`, or `config/environments/`. All work happens inside `.devcontainer/`.

### Step 1 — Create the feature branch

**Action**:

```bash
git fetch origin
git checkout rc-1.6.0
git pull origin rc-1.6.0
git checkout -b feat/codespaces-preview
```

**Exit criteria**:

- `git branch --show-current` prints `feat/codespaces-preview`.
- `git log -1 --format='%s'` matches the latest commit on `rc-1.6.0`.

### Step 2 — Create the `.devcontainer/` directory and its `.gitignore`

**Action**: create `.devcontainer/` and inside it `.gitignore` with:

```text
tess.preview.yml
secrets.preview.yml
```

**Exit criteria**:

- `ls .devcontainer/` shows `.gitignore`.
- `git status` shows the new file.

### Step 3 — Create `.devcontainer/pre-build.sh`

**Action**: write the script from [Deliverable #3](#3-devcontainerpre-buildsh-new--runs-on-the-host-before-container-start). Then:

```bash
chmod +x .devcontainer/pre-build.sh
```

**Exit criteria**:

- `bash -n .devcontainer/pre-build.sh` exits 0 (syntax-valid).
- `ls -l .devcontainer/pre-build.sh` shows the execute bit set.

### Step 4 — Create `.devcontainer/post-start.sh`

**Action**: write the script from [Deliverable #4](#4-devcontainerpost-startsh). Then:

```bash
chmod +x .devcontainer/post-start.sh
```

**Exit criteria**:

- `bash -n .devcontainer/post-start.sh` exits 0.
- Execute bit set.

### Step 5 — Create `.devcontainer/docker-compose.codespaces.yml`

**Action**: write the override file per [Deliverable #2](#2-devcontainerdocker-composecodespacesyml). It must override the `app` service (adding `.:/code` plus the two overlay mounts, `SECRET_KEY_BASE`, Slack env passthroughs, `depends_on: [mailhog]`, `restart: "no"`, `tty/stdin_open`), the `sidekiq` service (same), the `dbbackups` service (`profiles: ["disabled"]`), and add a new `mailhog` service.

**Exit criteria**:

- `docker compose -f docker-compose-prod.yml -f .devcontainer/docker-compose.codespaces.yml config` exits 0 (compose validates the merged spec).
- The output of that `config` command shows `app` with the new volume mounts and `mailhog` listed as a service.

### Step 6 — Create `.devcontainer/devcontainer.json`

**Action**: write the JSON per [Deliverable #1](#1-devcontainerdevcontainerjson). Key fields:

- `dockerComposeFile: ["../docker-compose-prod.yml", "docker-compose.codespaces.yml"]`
- `service: "app"`
- `workspaceFolder: "/code"`
- `forwardPorts: [3000, 8025]`
- `initializeCommand: "bash .devcontainer/pre-build.sh"`
- `postCreateCommand: "bash .devcontainer/post-start.sh"`
- `postStartCommand: "bash .devcontainer/post-start.sh"`

**Exit criteria**:

- `jq . .devcontainer/devcontainer.json` parses without error (file is valid JSON).
- No reference to `develop`, `master`, or any hardcoded hostname.

### Step 7 — Local sanity check (optional but recommended)

**Action**: from the repo root, on the host that has Docker:

```bash
bash .devcontainer/pre-build.sh
docker compose -f docker-compose-prod.yml -f .devcontainer/docker-compose.codespaces.yml up --build -d
sleep 60   # let Rails finish booting
docker compose -f docker-compose-prod.yml -f .devcontainer/docker-compose.codespaces.yml exec app bash .devcontainer/post-start.sh
curl -sI http://localhost:3000/ | head -1
curl -sI http://localhost:8025/ | head -1
docker compose -f docker-compose-prod.yml -f .devcontainer/docker-compose.codespaces.yml down -v
```

**Exit criteria**:

- Both `curl` commands return `HTTP/1.1 200 OK` (or `302`).
- `git status` shows ONLY new files under `.devcontainer/` — the tracked `config/tess.yml` must remain unchanged.
- The two `.devcontainer/*.preview.yml` files exist but are gitignored.

> If you don't have Docker locally, **skip this step** and rely on Step 9 in an actual Codespace.

### Step 8 — Commit and push

**Action**:

```bash
git add .devcontainer/
git status   # verify ONLY .devcontainer/ files are staged
git commit -m "Add GitHub Codespaces PR preview environment (prod-replica)"
git push -u origin feat/codespaces-preview
```

**Exit criteria**:

- `git log -1 --stat` shows only files under `.devcontainer/`.
- Branch is on GitHub.

### Step 9 — Open the PR against `rc-1.6.0` and verify in an actual Codespace

**Action**:

1. Open a PR from `feat/codespaces-preview` → `rc-1.6.0`. Use a descriptive title (e.g. "Add GitHub Codespaces PR preview environment").
2. Tag Nina or Harshita as reviewer; post the PR URL in Slack `#trainghub-portal`.
3. On the PR page, click **Code → Codespaces → Create codespace on this branch**.
4. Wait for the devcontainer to build (5–10 min first time). Watch the "Codespaces: Building image" / "Running postCreateCommand" log in the bottom-right.
5. Once VS Code opens in the browser, run the verification checks below.

**Verification checks (run inside the Codespace terminal)**:

- `git status` → must be clean (no modified tracked files).
- `ls .devcontainer/` → shows `tess.preview.yml` and `secrets.preview.yml` (generated by `pre-build.sh`).
- `docker compose ps` → all six services up: `app`, `db`, `solr`, `redis`, `sidekiq`, `mailhog`. (`dbbackups` should be absent / not started.)
- `docker compose exec app printenv RAILS_ENV` → `production`.
- `docker compose exec app printenv SLACK_BOT_USER_OAUTH_TOKEN` → empty string (no leak; safe default).
- `curl -sI http://localhost:3000/` → `HTTP/1.1 200 OK`.
- Open the auto-forwarded `https://<codespace>-3000.app.github.dev` URL in a new browser tab → TeSS home page renders, assets load, no "Missing host to link to!" errors anywhere in the page.
- Trigger a flow that sends mail (e.g. user invitation or password reset). Open `https://<codespace>-8025.app.github.dev` (MailHog UI) → captured email visible.
- No "Blocked host" errors in `docker compose logs app`.

**Exit criteria**:

- All verification checks pass.
- Reviewer can flip port `3000` to **Public** in the Ports tab and share the URL.

### Step 10 — Iteration test

**Action**: in the Codespace, edit any view file (e.g. `app/views/static/_home.html.erb`), save it, then:

```bash
docker compose -f docker-compose-prod.yml -f .devcontainer/docker-compose.codespaces.yml restart app sidekiq
docker compose -f docker-compose-prod.yml -f .devcontainer/docker-compose.codespaces.yml exec app bundle exec rake assets:precompile
```

Refresh the preview URL.

**Exit criteria**: the edit is visible. This confirms the bind-mount + restart workflow works for reviewers.

### Step 11 — Slack wiring (deferred — do AFTER PR merges, see TODOs)

The PR can merge with no Slack token configured (the default state). When you're ready to add Slack:

- Complete [TODO-1 (create test Slack bot)](#todo-1-create-a-dedicated-test-slack-bot-recommended-path).
- Complete [TODO-2 (add org-level Codespaces Secrets)](#todo-2-add-the-slack-token--channel-as-github-codespaces-secrets-org-level).
- No code change, no PR — restart any running Codespace and the env vars flow through.

### Step 12 — Update `README.md` (separate docs PR)

Tracked in `repo-docs-improvements.md` (TODO-4). Do as part of the broader docs cleanup PR; do NOT bundle into this PR.

---

## Acceptance / Success Criteria

A reviewer can:

1. Open any PR against an `rc-*` branch (the working branches in this fork).
2. Click **Code → Codespaces → Create codespace on this branch**.
3. Wait for the devcontainer to build (5–10 min first time, faster on subsequent boots due to Codespace caching) and `post-start.sh` to finish.
4. See port `3000` auto-forwarded, change its visibility to **Public**.
5. Open `https://<codespace-name>-3000.app.github.dev` and see TeSS running in **production mode** (precompiled assets, generic error pages, no dev console).
6. Push another commit, `git pull` inside the Codespace, run the documented refresh command → changes reflected.

…all without:

- Local Docker / Ruby setup.
- Access to the k8s cluster.
- Access to any production secret / image / DB.
- Any external infrastructure.

---

## Out of Scope (explicit non-goals)

- Production-grade Solr schema migration (preview uses the default `solr/` configset).
- Full ingestion / scraping runs (those depend on external APIs and `config/ingestion.yml`).
- LS-Login OIDC (use Devise database auth in previews).
- Real Slack / mailer delivery.
- Performance tuning (HPA, caching strategy, etc. — see `docs/hpa-scaling-guide.md` for prod).

---

## Manual Setup You (the Repo Owner) Need To Do Once

These are the things that cannot be automated from inside the repo, because they involve external systems (Slack, GitHub account/org settings). Do them once and reviewers get a working preview environment forever after.

> Until each of these is done, the preview environment still **works** (Rails boots, mail is captured by MailHog) — it just won't post to Slack. The default behaviour is safe.

### TODO-1: Create a dedicated test Slack bot (recommended path)

**Why**: keeps a hard blast-radius boundary between preview and prod. Even if the token leaks, a test bot installed only in a test channel physically cannot post to prod channels.

**Steps**:

1. In your Slack workspace (the same workspace that hosts the prod bot), go to <https://api.slack.com/apps> → **Create New App** → **From scratch**.
2. Name it `TeSS Preview Bot` (or similar). Pick the same workspace.
3. Under **OAuth & Permissions** → **Bot Token Scopes**, add ONLY:
   - `chat:write`
   - `chat:write.public` (optional — only if you want it to post to channels without being explicitly invited)
4. Click **Install to Workspace**. Approve. Copy the `xoxb-...` **Bot User OAuth Token**.
5. In Slack, invite the new bot ONLY to your test channel (e.g. `/invite @TeSS Preview Bot` inside `#tess-preview-test`). Do NOT invite it to any prod channel.
6. Stash the token somewhere safe for the next TODO.

**Acceptance**: the bot appears in `#tess-preview-test`’s member list and nowhere else.

### TODO-2: Add the Slack token + channel as GitHub Codespaces Secrets (org-level)

**Why**: this is how the token reaches the running preview container without ever touching the repo, `.env`, or compose files. Org-level means every reviewer's Codespace on this repo gets the same controlled test endpoint with zero per-user setup.

**Prerequisite**: org-owned Codespaces must be enabled (see TODO-7 below). This is done as of the org settings change on 2026-05-22.

**Steps**:

1. Go to `https://github.com/organizations/SciLifeLab-TrainingHub-Platform/settings/codespaces/secrets` (org settings → *Codespaces* → *Secrets*).
2. Click **New secret**. Name `SLACK_BOT_USER_OAUTH_TOKEN`, paste the test bot's `xoxb-...` token from TODO-1.
3. Under **Repository access** choose **Selected repositories** → pick `SciLifeLab-TrainingHub-Platform/TeSS` only. Do NOT use "All repositories" — keeps the blast radius scoped.
4. Save. Repeat for `SLACK_COURSE_NOTIFICATION_CHANNELS` with value `#tess-preview-test` (or whatever channel name your test bot is invited to).
5. If a Codespace is already running, restart it (or run `docker compose -f docker-compose-prod.yml -f .devcontainer/docker-compose.codespaces.yml restart app sidekiq` from inside it) so the new env vars are picked up.

**Fallback** (if you don't have org-admin access): same flow but at `https://github.com/settings/codespaces` (personal-level) — only your own Codespaces see the token; other reviewers get the safe-default empty-token behaviour and have to set up their own.

**Acceptance**: inside the Codespace, `docker compose exec app printenv SLACK_BOT_USER_OAUTH_TOKEN` shows the token (not empty), and triggering an event publish posts a message to `#tess-preview-test`.

### TODO-3 (only if you change the test bot later): Rotate the Codespaces Secret

When the test bot’s token is rotated/revoked, just update the value of `SLACK_BOT_USER_OAUTH_TOKEN` in <https://github.com/settings/codespaces> (or the org secrets page). No code change, no PR, no redeploy. Reviewers' next Codespace restart picks it up.

### TODO-4 (optional): Pick a test Slack channel name and document it

If your team agrees on a specific channel like `#tess-preview-test`, set it as the value of the `SLACK_COURSE_NOTIFICATION_CHANNELS` Codespaces Secret (TODO-2) so the default in the compose override is overridden. Otherwise the placeholder `#tess-preview-test` from the override is used — which will error harmlessly if the test bot isn't invited to a channel by that exact name.

### TODO-5: Codespaces Secrets ownership (RESOLVED — using org-level)

**Decision**: org-level Codespaces Secrets, after enabling org-owned Codespaces on 2026-05-22.

- **What changed**: org settings → *Codespaces* → *General* now has "Codespace ownership" set to org-owned. Any Codespace created on this repo by a member or collaborator is owned (and billed) by the org.
- **Why this matters for secrets**: `SLACK_BOT_USER_OAUTH_TOKEN` and `SLACK_COURSE_NOTIFICATION_CHANNELS` live at the org level (see TODO-2). Set once → every reviewer's preview gets them. No per-user setup, no "why doesn't Slack work in my Codespace?" support questions.
- **Why this matters for billing**: compute + storage are billed against the org's GitHub plan, NOT each reviewer's personal Codespaces quota. Predictable, governable. See TODO-7 below for the spending guardrails.
- **Why this matters for governance**: org admins can list/stop/delete any Codespace from `https://github.com/organizations/SciLifeLab-TrainingHub-Platform/settings/codespaces`. Useful if a Codespace gets stuck or a contributor leaves.

**Fallback if you ever need to revert to user-level** (e.g. plan downgrade): flip the org setting back, drop the org-level secrets, and have each reviewer set their own per-user secrets at `github.com/settings/codespaces`. The codebase needs no changes — the env-var passthrough in `.devcontainer/docker-compose.codespaces.yml` works either way.

### TODO-6 (NOT required, just a reminder): Do NOT use the prod Slack bot token

The override file deliberately defaults `SLACK_BOT_USER_OAUTH_TOKEN` to empty. If you ever feel tempted to set it to the prod token "just for a quick test" — don't. Use the test bot from TODO-1. The 5 minutes of setup is cheaper than one accidental prod post.

### TODO-7: One-time org admin setup for org-owned Codespaces (DO BEFORE INVITING REVIEWERS)

Now that Codespaces are org-owned, four small things in the org settings to make this safe + sustainable. All at `https://github.com/organizations/SciLifeLab-TrainingHub-Platform/settings/codespaces`.

1. **Spending limit** → `org settings → Billing and plans → Codespaces budget` (you have it open in the screenshot we discussed). Recommended starting value: **$50/month** with `Stop usage: Yes` so usage is hard-capped, not just warned. Re-evaluate after 4 weeks of real data. ($50 ≈ ~30 PR-preview sessions on the default 2-core machine — comfortable for a small team.)

2. **Email alert at 75%** of the budget — same edit page. Set recipient to whoever monitors infra cost. Gives you a week of headroom to either raise the cap or investigate runaway use before things get blocked mid-week.

3. **User permissions** → `org settings → Codespaces → General → Codespaces access`. Set to **All members** so any contributor can preview their PR without you having to add them individually. Switch to "Selected members" only if you start seeing abuse.

4. **Idle timeout & retention** → `org settings → Codespaces → Policies`:
   - **Maximum idle timeout**: leave default `30 min`. Don't raise — idle Codespaces are the main cost leak.
   - **Maximum retention period**: lower from default `30 days` to **`7 days`**. Devs can recreate a fresh Codespace from the PR in 5–10 min; no need to pay storage for stopped Codespaces for a month.

**Spot check after setting all of the above**: create a Codespace yourself from the PR, confirm it boots, then check `org settings → Codespaces` — your Codespace should show up in the org-owned list. If it shows under your personal account instead, the ownership setting didn't apply (re-check).

**Quick callout on the budgets dashboard**: the screenshot you shared shows `$0 budget` on Codespaces, Packages, Actions, and Git LFS. Only **Codespaces** needs to be raised for this work. The others can stay at `$0` if you're under their free allowances — quick check: if the repo `SciLifeLab-TrainingHub-Platform/TeSS` is **private** AND CI pushes images to `ghcr.io`, the Packages budget would also need raising (public-repo packages are free, private-repo packages are paid past a tiny free tier).

### Quick reference: where things live

| Thing | Where it lives | Who sets it |
| --- | --- | --- |
| Test Slack bot + token | `api.slack.com/apps` | Repo owner (you), once |
| `SLACK_BOT_USER_OAUTH_TOKEN` | GitHub Codespaces Secrets (org-level, scoped to this repo) | Repo owner / org admin |
| `SLACK_COURSE_NOTIFICATION_CHANNELS` | GitHub Codespaces Secrets (org-level, scoped to this repo), defaulted in `.devcontainer/docker-compose.codespaces.yml` | Repo owner / org admin |
| Codespaces compute + storage budget | Org billing → Codespaces budget ($50/mo starting cap with hard-stop) | Org admin |
| Codespaces ownership / access policy | Org settings → Codespaces (org-owned, all members) | Org admin |
| MailHog SMTP host/port | Auto-injected by `pre-build.sh` into `.devcontainer/secrets.preview.yml` | Nothing — automatic |
| `base_url` for URL helpers | Patched into `.devcontainer/tess.preview.yml` by `post-start.sh` using `${CODESPACE_NAME}` | Nothing — automatic |
| `SECRET_KEY_BASE` | Hard-coded placeholder in `.devcontainer/docker-compose.codespaces.yml` | Nothing — automatic |

## Open Questions for the Reviewer

1. Do we want previews on **every** PR or only on PRs targeting `rc-*` branches? (Codespaces is manual-launch, so naturally opt-in.)
2. Are we OK with the cold-start cost (5–10 min for full `bundle install` + `assets:precompile` at image build time)? If not, we can add a build cache volume in v2.
3. Do we want `bin/preview-refresh` shipped as a helper, or is the long `docker compose` command in `post-start.sh` output enough?
4. Do we want a separate, preview-only seed file (e.g. `db/seeds/preview.rb`) with a few fake events/courses for reviewer convenience? Current `db/seeds.rb` should be audited for "preview-safety" before we rely on it.
5. Is anything in our (private) `config/environments/production.rb` likely to break in a Codespace context (e.g. SSL enforcement, asset CDN host)? Worth a quick read before implementation.
