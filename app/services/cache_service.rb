# frozen_string_literal: true

class CacheService
  DEFAULT_EXPIRY = 1.hour

  def self.read(key)
    Rails.cache.read(namespaced(key))
  end

  def self.write(key, value, expires_in: DEFAULT_EXPIRY)
    Rails.cache.write(namespaced(key), value, expires_in: expires_in)
  end

  def self.fetch(key, expires_in: DEFAULT_EXPIRY, &block)
    Rails.cache.fetch(namespaced(key), expires_in: expires_in, &block)
  end

  def self.delete(key)
    Rails.cache.delete(namespaced(key))
  end

  def self.exist?(key)
    Rails.cache.exist?(namespaced(key))
  end

  def self.claim_once(key, expires_in: DEFAULT_EXPIRY)
    Rails.cache.write(namespaced(key), true, expires_in: expires_in, unless_exist: true)
  end

  def self.namespaced(key)
    "cache_service:#{key}"
  end
  private_class_method :namespaced
end
