class CookieConsent
  OPTIONS = %w(necessary_v2 tracking).freeze
  LEGACY_ALIASES = {
    'necessary' => 'necessary_v2'
  }.freeze

  def initialize(store)
    @store = store
  end

  def options=(opts)
    opts = opts.to_s.split(',').map(&:strip)
    opts = opts.map { |opt| LEGACY_ALIASES.fetch(opt, opt) }.uniq
    @store[:cookie_consent] = opts.join(',') unless opts.any? { |opt| !OPTIONS.include?(opt) }
  end

  def options
    (@store[:cookie_consent] || '')
      .split(',')
      .map(&:strip)
      .map { |opt| LEGACY_ALIASES.fetch(opt, opt) }
      .select { |opt| OPTIONS.include?(opt) }
      .uniq
  end

  def revoke
    @store[:cookie_consent] = nil
  end

  def required?
    TeSS::Config.require_cookie_consent
  end

  def given?
    options.any?
  end

  def show_banner?
    required? && !given?
  end

  def allow_tracking?
    !required? || options.include?('tracking')
  end

  def allow_necessary?
    !required? || options.include?('necessary_v2')
  end
end
