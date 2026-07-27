# Rate limiting course-interest subscribe/unsubscribe emails (#465)

Design & recommendation doc. Status: proposal for discussion.

## 1. Problem

Guests can trigger a confirmation email by POSTing to the course-interest
subscribe/unsubscribe endpoint (`CourseSubscriptionsController#request_email_action`
→ `CourseInterestService.request_subscription!` / `request_unsubscription!`). With no
throttle, a bot can:

- **spam one address** with repeated confirmation emails, and/or
- **spray many addresses** (email-bombing victims, one confirmation each).

Ticket #465 asks for interim rate limiting. (The "proper" fix — email → click → a
dedicated unsubscribe page with a POST — is a separate ticket needing Nina's sign-off;
rate limiting does not replace it.)

## 2. What the draft (PR #476) implemented

- `CacheService` — wrapper over `Rails.cache`; key method `claim_once(key, expires_in:)`
  = `Rails.cache.write(key, true, unless_exist: true, expires_in:)` (a "claim/cooldown").
- `CourseInterestService` — before sending, `claim_once((action, course.id, sha256(email)), 1.minute)`;
  on failure returns a "please wait a minute" error.

Net: a **1-minute per-(email, course, action) cooldown**. Placement, key hashing, and the
cooldown idea are all sound. **Only the storage backend is wrong for our environment.**

## 3. Why it's blocked, and why `Rails.cache` is the wrong backend here

Three independent problems, any one of which is disqualifying:

1. **The Rails 7.0 expiry bug (the blocker they hit).** In Rails < 7.1,
   `ActiveSupport::Cache::RedisCacheStore#write(unless_exist: true, expires_in: X)` issues
   Redis `SET k v NX` **without** the `EX` TTL — so the key never expires and the cooldown
   becomes a **permanent lockout**. Fixed in Rails 7.1 (writes now use `SET … NX EX ttl`).
   This matches the symptom in the PR description ("doesn't clear out old entries once they
   expire"). Crucially, this is a bug in the **ActiveSupport::Cache layer**, not in Redis.

2. **`Rails.cache` is per-environment mis-configured for a shared counter.**
   - dev = `:null_store` → `claim_once` never persists → **never rate limits, can't be tested locally**.
   - prod = `:file_store` (cache_store is commented out in `config/environments/production.rb`) →
     **per-pod local disk**. `th-app` runs **2 replicas** (confirmed via `kubectl -n th-dev get pods`),
     so the cooldown only applies within whichever pod served the first request; the other pod has no
     record → the limit is effectively 2× and non-deterministic.

3. Therefore, even switching `config.cache_store = :redis_cache_store` (fixing #2) would **still**
   hit the 7.0 `unless_exist` bug (#1), because you'd still go through `ActiveSupport::Cache`.

**Conclusion: use Redis directly (native commands), not `Rails.cache`.** Native `SET k 1 NX EX 60`
includes the TTL, so it is unaffected by the 7.0 bug, is shared across all pods, and works in dev
(real Redis in docker-compose). **This does NOT require waiting for the Rails 7.1 upgrade.**

Redis is already a hard dependency (Sidekiq, ActionCable) and direct use is already an established
pattern — see `lib/fairsharing/client.rb` (`Redis.new(url: TeSS::Config.redis_url)`). The
`connection_pool` gem is already available.

## 4. Recommended design

Keep Adeel's structure; swap the backend and add a second dimension.

### 4.1 A small `RateLimiter` service (native Redis)

```
RateLimiter.cooldown?(key, ttl)      # SET key 1 NX EX ttl -> true if within cooldown (claim failed)
RateLimiter.over_limit?(key, ttl, n) # INCR key; EXPIRE key ttl if count == 1; true if count > n
```

- Reuse `TeSS::Config.redis_url`; wrap a `ConnectionPool` of `Redis` clients (pattern from the
  fairsharing client).
- Namespace keys: `ratelimit:course_interest:…` so they never collide with Sidekiq's keys in the
  shared Redis DB.

### 4.2 Two limits, checked before sending

1. **Per-(email, course, action) cooldown** (keeps Adeel's behavior): `SET NX EX` with e.g. 60s.
   Stops rapid resends to the same address.
2. **Per-IP window** (new — closes the spray gap): `INCR`/`EXPIRE`, e.g. max 10 confirmation
   emails per IP per hour. Requires passing the request IP from the controller into the service.

Whichever limit trips first blocks the send.

### 4.3 Behavior details

- **Enumeration safety.** Prefer returning the existing `GENERIC_SUBSCRIBE_MESSAGE` (and silently
  skipping the send) over a distinct "please wait" error, so the limiter isn't an oracle for
  "this address was recently submitted." (Draft currently returns a distinct message — acceptable,
  but this is stricter. Team decision.)
- **Fail-open.** If Redis is unreachable, allow the send and log a warning — a Redis blip should not
  break legitimate subscribes. (Draft is effectively fail-closed: a cache error bubbles to the
  service's rescue → "Something went wrong".)
- **Config-driven.** Put windows/limits in `TeSS::Config` (tess.yml + tess.example.yml) per repo
  convention, not hard-coded constants.
- **Keys** stay SHA256(email) + course id + action, as in the draft.

## 5. Migration from the draft (minimal)

- Replace `CacheService.claim_once` with `RateLimiter.cooldown?` (native Redis) — or repurpose
  `CacheService` to talk to Redis directly instead of `Rails.cache`.
- Add the per-IP `over_limit?` check; thread `request.remote_ip` from
  `CourseSubscriptionsController#request_email_action` into the service call.
- Move durations into `TeSS::Config`.
- Decide message (generic vs explicit) and fail-open.

## 6. Testing

- Unit-test `RateLimiter` against the dev/test Redis (real Redis in docker; do NOT stub away the TTL).
- Service tests: first request sends; immediate second (same email+course) is blocked; after TTL it
  sends again; N+1th request from one IP is blocked. Because we use real Redis (not NullStore), these
  are actually meaningful — unlike the `Rails.cache` version in dev/test.

## 7. Ops notes

- Shares the Sidekiq Redis (single `REDIS_URL`). Traffic is tiny vs job traffic; namespaced keys keep
  it tidy. No k8s/deployment change needed — pods already have `REDIS_URL`.
- Confirm Redis `maxmemory-policy` is `noeviction` (Sidekiq requires it anyway) so counters aren't
  evicted early; TTLs handle cleanup.

## 8. Open decisions for the team

1. Limits: cooldown seconds (60?) and per-IP cap/window (10/hour?).
2. Message on rate-limit: generic (enumeration-safe) vs explicit "please wait".
3. Fail-open (recommended) vs fail-closed.
4. Do we also want a Rack-layer IP throttle (rack-attack) as defense-in-depth? If so, point its store
   at native Redis, not `RedisCacheStore` (same 7.0 bug otherwise).
