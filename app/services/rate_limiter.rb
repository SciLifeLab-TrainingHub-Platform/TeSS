# frozen_string_literal: true

# Small rate limiter backed by Redis using *native* atomic commands.
#
# Why native Redis instead of Rails.cache:
#   1. Rails < 7.1 has a bug where ActiveSupport::Cache::RedisCacheStore#write
#      with `unless_exist: true` issues `SET NX` WITHOUT the `EX` TTL, so the
#      key never expires and a cooldown becomes a permanent lockout. Calling
#      Redis directly with `SET key 1 NX EX ttl` includes the TTL and sidesteps
#      the bug entirely (works on our current Rails 7.0).
#   2. Rate limits must be shared across all app pods. Rails.cache here is
#      :null_store in development (never limits, untestable) and :file_store in
#      production (per-pod local disk; the th-app Deployment runs multiple
#      replicas). Redis is the single shared store both Sidekiq and ActionCable
#      already use.
#
# Both methods FAIL OPEN: if Redis is unreachable we allow the action and log a
# warning, so a Redis blip never blocks legitimate users.
class RateLimiter
  NAMESPACE = 'ratelimit'

  class << self
    # Cooldown / claim: allow the first call for `key`, then block until `ttl`
    # elapses. Returns true when the action is ALLOWED (claim succeeded), false
    # when the caller is still within the cooldown window.
    #
    # Implemented as an atomic `SET key 1 NX EX ttl`.
    def allow_once?(key, ttl:)
      with_redis do |redis|
        redis.set(namespaced(key), 1, nx: true, ex: ttl.to_i) ? true : false
      end
    rescue StandardError => e
      log_failure('allow_once?', e)
      true
    end

    # Fixed-window counter: allow up to `limit` calls per `ttl` seconds for
    # `key`. Returns true while the count is within the limit, false once it is
    # exceeded.
    #
    # Implemented as `INCR key` (+ `EXPIRE key ttl` on the first hit so the
    # window resets). INCR is atomic across pods.
    def within_limit?(key, limit:, ttl:)
      with_redis do |redis|
        namespaced_key = namespaced(key)
        count = redis.incr(namespaced_key)
        redis.expire(namespaced_key, ttl.to_i) if count == 1
        count <= limit
      end
    rescue StandardError => e
      log_failure('within_limit?', e)
      true
    end

    private

    def with_redis(&block)
      pool.with(&block)
    end

    def pool
      @pool ||= ConnectionPool.new(size: 5, timeout: 2) do
        Redis.new(url: TeSS::Config.redis_url)
      end
    end

    def namespaced(key)
      "#{NAMESPACE}:#{key}"
    end

    def log_failure(operation, error)
      Rails.logger.warn(
        "RateLimiter##{operation} failed, failing open: #{error.class} - #{error.message}"
      )
    end
  end
end
