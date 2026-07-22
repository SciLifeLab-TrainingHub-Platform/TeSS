# frozen_string_literal: true

module LogRedactor
  module_function

  CONTROL_CHARS = /[\x00-\x1f\x7f]/

  def email_log_id(email)
    return nil if email.blank?
    user, domain = email.split("@", 2)
    return "[redacted]" if domain.blank?
    first_char = user[0].to_s.gsub(CONTROL_CHARS, "")
    safe_domain = domain.gsub(CONTROL_CHARS, "")
    "#{first_char}***@#{safe_domain}"
  end
end
