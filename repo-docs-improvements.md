# Repo Documentation & Infra Improvements (TODO Tracker)

Stuff we noticed is outdated or missing in the repo's user-facing docs and infrastructure while working on other tasks. Not blocking anything — capture-and-defer list so each gets fixed in a dedicated PR later.

Source of truth for everything below is `.github/workflows/build.yaml` + the actual `Dockerfile` + current practice, not the existing markdown.

---

## TODO-1: `README.md` — Branching section is outdated

**File**: `README.md` (the SciLifeLab fork-specific block at the top, roughly lines 6–18).

**What's wrong today**:

- Tells contributors to "Start with develop branch, create your feature branch".
- Mentions `develop` as the default working branch.
- Recommends a feature branch naming convention of `name_feature` (e.g. `harshita_searchfunc`).
- Says `master` is read-only mirror of upstream — this part is still correct.

**What it should say**:

- Working branches are `rc-*`. **Currently active: `rc-1.6.0`** (update this whenever a new release cycle starts).
- Feature branches use the convention **`feat/<short-description>`** (e.g. `feat/search-functionality`, `feat/codespaces-preview`). The old `name_feature` convention is no longer used.
- Feature branches should be branched off the current active `rc-*` and opened back into the same `rc-*` via PR.
- `develop` is NOT used by current workflows.
- `master` remains read-only mirror of upstream `ElixirTeSS/TeSS` — never push to it.
- The reviewer/Slack-notification flow (Nina or Harshita; `#trainghub-portal` channel) stays as-is.

**Suggested wording sketch** (for the future PR):

> ### Contributions to code
>
> 1. Identify the current active `rc-*` branch (currently `rc-1.6.0`; ask in `#trainghub-portal` if unsure — it rolls over each release cycle). Branch off it.
> 2. Name your feature branch `feat/<short-description>` (e.g. `feat/search-functionality`). Lowercase, kebab-case, no personal names.
> 3. Open a PR back into the same `rc-*` branch. This automatically triggers the dev image build via `.github/workflows/build.yaml`.
> 4. Add Nina or Harshita as reviewer, and ping the PR URL in Slack `#trainghub-portal`.
> 5. `master` is a read-only mirror of upstream `ElixirTeSS/TeSS`. Never push to it.

---

## TODO-2: `README.md` — Add CI/CD trigger map

Right now there's no documented connection between branch/tag/release events and what gets built/deployed. A short table would save a lot of "where does this go?" questions.

**Suggested addition** under a new `## CI/CD` heading:

| Event | Branch/Tag pattern | What happens | Image target |
| --- | --- | --- | --- |
| PR opened/sync/reopen | against `rc-*` | Tests + dev image build | `ghcr.io/.../tess-app-dev:<datestamp>-<branch>` |
| Push | to `rc-*` | Dev image build & push | `...-dev:<datestamp>-<branch>` |
| Tag created | `rc-v*` | Pre-prod image build & push | `...-preprod:<tag>` |
| Release published | any | Prod image build & push | `...-prod:<release-tag>` |
| Manual `workflow_dispatch` | any | Build for chosen env (`dev`/`preprod`/`prod`) | corresponding tag |

(Pulled from `.github/workflows/build.yaml`.)

---

## TODO-3: `CONTRIBUTING.md` — Fork-specific addendum

**File**: `CONTRIBUTING.md`.

**What's wrong today**: it's the upstream `ElixirTeSS/TeSS` contributor guide verbatim. It references:

- `master` as the base branch for feature branches (line 70 area).
- Upstream fork workflow (fork → branch → PR back to upstream).

That entire flow does NOT apply to this fork. Internal contributors don't fork the SciLifeLab repo — they branch directly off `rc-*` and PR within the same repo.

**Fix options** (pick one for the future PR):

- **Option A (minimal)**: add a short SciLifeLab-specific section at the very top that overrides the upstream guidance, leave the rest as-is for upstream alignment.
- **Option B (cleaner)**: split into `CONTRIBUTING.md` (this fork's flow) + `CONTRIBUTING-UPSTREAM.md` (preserved upstream guide).

Recommend Option A — less churn, no information loss.

---

## TODO-4: `README.md` — Add a "Preview environments" section (once Codespaces lands)

After the `.devcontainer/` work from `plan-preview-env.md` is merged, add a short README section like:

> ### Previewing a PR
>
> Every PR can be previewed in a production-replica environment via GitHub Codespaces:
>
> 1. On the PR, click **Code → Codespaces → Create codespace on this branch**.
> 2. Wait ~5–10 min for the production image to build.
> 3. Open the auto-forwarded port `3000`. To share externally, set its visibility to **Public** in the Codespaces "Ports" tab.
> 4. Captured emails are visible at port `8025` (MailHog).
> 5. See `.devcontainer/` for the setup, and `plan-preview-env.md` for the design notes.

Should NOT be added until the `.devcontainer/` files actually exist on the relevant `rc-*` branch — otherwise we'd be advertising something that doesn't work yet.

---

## TODO-5: Audit `docs/` for the same `develop`/`master` confusion

Files to skim during the future docs PR:

- `docs/docker.md` — installation guide; check the branching note at the top.
- `docs/install.md` — same.
- `docs/production.md` — does it reference branches or tags?
- `docs/customization.md` — probably upstream-aligned, probably fine.
- `docs/integration-guide.md` — check for references to deployment branches.

Anywhere they say "checkout the develop branch" or "branch off master", correct to the `rc-*` model.

---

## TODO-6: Document where to find the current `rc-*` branch name

Contributors keep having to ask "which `rc-*` is current?". As of writing the active branch is **`rc-1.6.0`**. Options to keep this discoverable:

- Pin a Slack message in `#trainghub-portal` with the active branch + last-updated date.
- Add a one-line note in `README.md` near the contributing section: "Active branch is currently `rc-1.6.0` (updated when a new release cycle starts; ask in `#trainghub-portal` if in doubt)."
- Better: use a GitHub repo label or a `.github/CODEOWNERS`-style file pointing at the active branch — but this is over-engineering for a 5-person team. Pinned Slack message + README line is fine.

---

## TODO-7: Sync `CLAUDE.md` cross-references

`CLAUDE.md` was just updated to reflect the `rc-*` workflow (see commit history). When `README.md` is fixed (TODO-1, TODO-2), double-check that any cross-references between the two stay consistent. Likely just one quick re-read.

---

## TODO-9: DX — Optional local-sim "insecure cookies" toggle for Codespaces preview

**Trigger**: only if the team starts relying on local Docker simulation (instead of actual Codespaces) for routine PR preview work. Not needed if everyone always uses real Codespaces.

**Context**: `config/initializers/session_store.rb` sets `secure: true` on the session cookie when `Rails.env.production?`. Our Codespaces preview env runs `RAILS_ENV=production` (it's a production replica) — which means:

- In a real Codespace at `https://<name>-3000.app.github.dev` → HTTPS → cookie stored → CSRF works → POSTs (login, cookie consent, forms) all succeed.
- In the local Docker simulation at `http://localhost:3000` → no HTTPS → browser silently discards the secure cookie → no server-side CSRF state → every POST returns **HTTP 422** (the cookie consent banner button being the obvious one).

This is documented in `.devcontainer/post-start.sh`'s banner so devs running the local sim aren't surprised, but it does mean local sim cannot fully validate POST-only flows.

**Proposed fix** (do only if needed):

1. Add `LOCAL_SIM_INSECURE_COOKIES=${LOCAL_SIM_INSECURE_COOKIES:-}` env to `.devcontainer/docker-compose.codespaces.yml` (defaults to empty → no behaviour change in real Codespaces).
2. Add a small bind-mounted initializer override (e.g. `.devcontainer/local-sim-initializer.rb` mounted RO at `/code/config/initializers/zz_local_sim_session.rb`) that re-applies the session store WITHOUT `secure: true` when the env var is set.
3. Document the env var in `plan-preview-env.md` and `post-start.sh` banner.

**Why we didn't ship this now**: real Codespaces is the actual target environment, and a defensive local-sim override risks devs forgetting it's there and shipping insecure-cookie configs by mistake. Adding it later, with a clear opt-in pattern, is safer than baking it into v1.

---

## TODO-8: INFRA — Slim `Dockerfile` & enforce non-root user

**Trigger**: do this AFTER `.devcontainer/` (the PR preview env, tracked in `plan-preview-env.md`) is merged and a few PRs have been previewed successfully. Reason: changing the Dockerfile while the preview env is being adopted would risk conflating "preview env broke" with "image change broke".

**Why this matters**:

- The current `production` stage in `Dockerfile` runs the Rails process as `root`. K8s deployments increasingly enforce `PodSecurityStandard: restricted` / `runAsNonRoot: true`, and our cluster will get there. Better to fix the image now than to scramble when a security policy lands.
- The image size is larger than it needs to be (we're shipping build-time tooling, intermediate gem caches, possibly node_modules, etc.) which makes pulls slower in CI, in Codespaces, and in every prod deploy.

**Scope of the task** (high-level — do a proper plan when this comes up):

1. **Audit current state**
   - `docker images tess-app` → record current size as a baseline.
   - `docker history tess-app` → identify which layers contribute the most.
   - Verify exactly what's still in `/code` at runtime that doesn't need to be (e.g. `node_modules` after asset compile, `.git`, test fixtures, `docs/`, `tmp/cache/assets/sprockets/*`).

2. **Convert to a clean multi-stage build** (likely already partially there — `target: production` is referenced in compose):
   - `gems-build` stage: ruby + build-essential + native gem compile deps; produces `/usr/local/bundle`.
   - `assets-build` stage: ruby + node + yarn; produces `public/assets`.
   - `runtime` stage: minimal ruby (no build tools, no node, no yarn). COPY only the gems and assets from previous stages.

3. **Non-root user**
   - Create a `tess` user + group with a fixed UID/GID (e.g. 1000:1000 — coordinate with whatever the K8s `runAsUser` will be).
   - `chown -R tess:tess /code` (and any other writable dirs: `/code/tmp`, `/code/log`, `/code/public/system`).
   - `USER tess` as the last instruction before `CMD`.
   - Verify volume mounts in `docker-compose-prod.yml` and the K8s manifests still work with this UID (especially `uploads`, `logs`, `db-backups`).

4. **Codespaces preview compatibility**
   - The `.devcontainer/` setup currently relies on `remoteUser: root` in `devcontainer.json` because the image runs as root. After the non-root switch, change that to `remoteUser: tess` and re-test the full preview lifecycle (`pre-build.sh`, `post-start.sh`, `bundle install`, `db:prepare`, `assets:precompile`, file writes to bind mounts).
   - The bind mount of `.:/code` will need attention: on Linux/Codespaces the host UID must match the container UID for writes to work cleanly. The devcontainer CLI / Codespaces handle this via `updateRemoteUserUID`; just make sure that's enabled.

5. **Verify in all three runtimes**
   - Local `docker compose -f docker-compose-prod.yml up` → app boots, no permission errors, file uploads work.
   - Codespaces preview → full lifecycle works as it did before.
   - Dev K8s cluster → deploy with `runAsNonRoot: true` + `runAsUser: 1000` + `readOnlyRootFilesystem: true` (the last one will surface any remaining writable-path assumptions).

6. **Document the change**
   - Update `docs/docker.md` and `docs/production.md` if any commands change.
   - Update `CLAUDE.md` if architecture notes change.

**Open questions** (decide before starting):

- Are we doing **just the `production` target**, or also tightening the `development` target (`Dockerfile.dev` if it exists, or the relevant stage)? User intent ("optimising dockerfile-dev as well") says BOTH — confirm at start.
- Target image size? Set a goal (e.g. "<800 MB", currently let's say it's ~1.5 GB) so we know when we're done vs over-engineering.
- Pin the `tess` UID:GID early — once chosen, changing it later requires re-chowning every persistent volume.

**Risk if we skip this**:

- K8s security policy upgrade forces an emergency Dockerfile change later under time pressure.
- Every cold pull (in CI, Codespaces, new prod nodes) wastes a few minutes on bloated layers.

---

## Process for tackling this

Suggest doing all of these in ONE small docs-only PR, against the current `rc-*` branch. Keep it scoped to documentation — no code, no `.devcontainer/`, no workflow changes — so the review is fast and there's no risk to running services.
