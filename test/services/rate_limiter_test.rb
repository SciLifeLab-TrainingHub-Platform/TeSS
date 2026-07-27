# frozen_string_literal: true

require 'test_helper'

class RateLimiterTest < ActiveSupport::TestCase
  # Unique key per test so a leftover TTL from a previous run can't leak in.
  def setup
    @key = "test:#{SecureRandom.hex(6)}"
  end

  test 'allow_once? claims on first call and blocks within the cooldown window' do
    assert RateLimiter.allow_once?(@key, ttl: 60), 'first call should be allowed (claim)'
    refute RateLimiter.allow_once?(@key, ttl: 60), 'second call within window should be blocked'
  end

  test 'allow_once? is independent per key' do
    assert RateLimiter.allow_once?(@key, ttl: 60)
    assert RateLimiter.allow_once?("#{@key}:other", ttl: 60), 'a different key should not be affected'
  end

  test 'within_limit? allows up to the limit then blocks' do
    assert RateLimiter.within_limit?(@key, limit: 2, ttl: 60), '1st within limit'
    assert RateLimiter.within_limit?(@key, limit: 2, ttl: 60), '2nd within limit'
    refute RateLimiter.within_limit?(@key, limit: 2, ttl: 60), '3rd exceeds limit'
  end

  test 'fails open when Redis is unavailable' do
    broken = ConnectionPool.new(size: 1, timeout: 1) { Redis.new(url: 'redis://127.0.0.1:6390/0') }
    RateLimiter.stub(:pool, broken) do
      assert RateLimiter.allow_once?(@key, ttl: 60), 'allow_once? should fail open'
      assert RateLimiter.within_limit?(@key, limit: 1, ttl: 60), 'within_limit? should fail open'
    end
  end
end
