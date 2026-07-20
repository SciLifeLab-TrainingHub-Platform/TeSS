# frozen_string_literal: true

module LogRedactor
  module_function

  def email_log_id(email)
    return nil if email.blank?
    user, domain = email.split("@", 2)
    return "[redacted]" if domain.blank?
    "#{user[0]}***@#{domain}"
  end
end