# frozen_string_literal: true

class CourseInterestService
  extend LogRedactor

  # Cooldown per (email, course, action): stops rapid resends to one address.
  EMAIL_RATE_LIMIT_DURATION = 1.minute
  # Per-IP window: stops one actor spraying confirmation emails to many addresses.
  IP_RATE_LIMIT = 10
  IP_RATE_LIMIT_WINDOW = 1.hour
  COURSE_INTEREST_TOKEN_EXPIRY = 7.days

  GENERIC_SUBSCRIBE_MESSAGE = "If that email isn't already subscribed, we've sent a confirmation link."
  RATE_LIMITED_MESSAGE = "Please wait a moment before requesting another email for this course."

  def self.subscribe_user!(course:, user:)
    result = CourseInterest.subscribe!(
      course: course,
      user: user
    )

    case result
    when CourseInterest::RESULT_SUBSCRIBED
      { status: :ok, message: "You have subscribed successfully", result: result }

    when CourseInterest::RESULT_UNAUTHENTICATED
      { status: :error, message: "You must be logged in to register interest", result: result }

    when CourseInterest::RESULT_ALREADY_SUBSCRIBED
      { status: :ok, message: "You are already subscribed", result: result }

    when CourseInterest::RESULT_INVALID
      { status: :error, message: "Invalid request", result: result }

    else
      Rails.logger.error "Unexpected CourseInterest.subscribe! result: #{result.inspect} for course ##{course.id}, user ##{user.id}"
      { status: :error, message: "Something went wrong", result: result }
    end

  rescue StandardError => e
    Rails.logger.error "CourseInterestService.subscribe_user! failed for course ##{course&.id}, user ##{user&.id}: #{e.class} - #{e.message}"
    { status: :error, message: "Something went wrong", result: nil }
  end

  def self.unsubscribe_user!(course:, user:)
    result = CourseInterest.unsubscribe!(
      course: course,
      user: user
    )

    case result
    when CourseInterest::RESULT_UNSUBSCRIBED
      { status: :ok, message: "You have unsubscribed successfully", result: result }

    when CourseInterest::RESULT_NOT_SUBSCRIBED
      { status: :ok, message: "You are not currently subscribed", result: result }

    when CourseInterest::RESULT_UNAUTHENTICATED
      { status: :error, message: "You must be logged in to un-register interest", result: result }

    when CourseInterest::RESULT_INVALID
      { status: :error, message: "Invalid request", result: result }

    else
      Rails.logger.error "Unexpected CourseInterest.unsubscribe! result: #{result.inspect} for course ##{course.id}, user ##{user.id}"
      { status: :error, message: "Something went wrong", result: result }
    end

  rescue StandardError => e
    Rails.logger.error "CourseInterestService.unsubscribe_user! failed for course ##{course&.id}, user ##{user&.id}: #{e.class} - #{e.message}"
    { status: :error, message: "Something went wrong", result: nil }
  end

  def self.request_subscription!(course:, email:, ip: nil)
    if rate_limited?(course: course, email: email, ip: ip, action_type: CourseInterest::ACTION_REQUEST_SUBSCRIBE)
      return rate_limited_response
    end

    result, interest = CourseInterest.request_subscribe!(
      course: course,
      email: email
    )

    case result
    when CourseInterest::RESULT_PENDING
      token = generate_subscription_token(
        interest,
        CourseInterest::TOKEN_PURPOSE_SUBSCRIPTION
      )

      CourseSubscriptionMailer
        .subscription_confirmation(email, course, token)
        .deliver_later

      { status: :ok, message: GENERIC_SUBSCRIBE_MESSAGE, result: result }

    when CourseInterest::RESULT_ALREADY_SUBSCRIBED
      { status: :ok, message: GENERIC_SUBSCRIBE_MESSAGE, result: result }

    when CourseInterest::RESULT_INVALID
      { status: :error, message: "Invalid request", result: result }

    else
      Rails.logger.error "Unexpected CourseInterest.request_subscribe! result: #{result.inspect} for course ##{course.id}, email_hash=#{email_log_id(email)}"
      { status: :error, message: "Something went wrong", result: result }
    end

  rescue StandardError => e
    Rails.logger.error "CourseInterestService.request_subscription! failed for course ##{course&.id}, email_hash=#{email_log_id(email)}: #{e.class} - #{e.message}"
    { status: :error, message: "Something went wrong", result: nil }
  end

  def self.request_unsubscription!(course:, email:, ip: nil)
    if rate_limited?(course: course, email: email, ip: ip, action_type: CourseInterest::ACTION_REQUEST_UNSUBSCRIBE)
      return rate_limited_response
    end

    result, interest = CourseInterest.request_unsubscribe!(
      course: course,
      email: email
    )

    case result
    when CourseInterest::RESULT_PENDING
      token = generate_subscription_token(
        interest,
        CourseInterest::TOKEN_PURPOSE_UNSUBSCRIPTION
      )

      CourseSubscriptionMailer
        .unsubscription_confirmation(email, course, token)
        .deliver_later

      { status: :ok, message: "Unsubscription confirmation email sent", result: result }

    when CourseInterest::RESULT_NOT_SUBSCRIBED
      { status: :ok, message: "You are not currently subscribed", result: result }

    when CourseInterest::RESULT_INVALID
      { status: :error, message: "Invalid request", result: result }

    else
      Rails.logger.error "Unexpected CourseInterest.request_unsubscribe! result: #{result.inspect} for course ##{course.id}, email_hash=#{email_log_id(email)}"
      { status: :error, message: "Something went wrong", result: result }
    end

  rescue StandardError => e
    Rails.logger.error "CourseInterestService.request_unsubscription! failed for course ##{course&.id}, email_hash=#{email_log_id(email)}: #{e.class} - #{e.message}"
    { status: :error, message: "Something went wrong", result: nil }
  end

  def self.confirm_subscription!(interest:)
    result = CourseInterest.confirm_subscription(interest)

    case result
    when CourseInterest::RESULT_SUBSCRIBED
      { status: :ok, message: "Subscription confirmed successfully", result: result }

    when CourseInterest::RESULT_ALREADY_SUBSCRIBED
      { status: :ok, message: "You are already subscribed", result: result }

    when CourseInterest::RESULT_ALREADY_UNSUBSCRIBED
      { status: :error, message: "This subscription link is no longer valid", result: result }

    when CourseInterest::RESULT_INVALID
      { status: :error, message: "Invalid subscription link", result: result }

    else
      Rails.logger.error "Unexpected CourseInterest.confirm_subscription result: #{result.inspect} for interest ##{interest.id}"
      { status: :error, message: "Something went wrong", result: result }
    end

  rescue StandardError => e
    Rails.logger.error "CourseInterestService.confirm_subscription! failed for interest ##{interest&.id}: #{e.class} - #{e.message}"
    { status: :error, message: "Something went wrong", result: nil }
  end

  def self.confirm_unsubscription(interest)
    result = CourseInterest.confirm_unsubscription(interest)

    case result
    when CourseInterest::RESULT_UNSUBSCRIBED
      { status: :ok, message: "You have been unsubscribed successfully", result: result }

    when CourseInterest::RESULT_ALREADY_UNSUBSCRIBED
      { status: :ok, message: "This course is already unsubscribed for the email provided.", result: result }

    when CourseInterest::RESULT_NOT_SUBSCRIBED
      { status: :ok, message: "Course subscription not found", result: result }

    when CourseInterest::RESULT_INVALID
      { status: :error, message: "Invalid unsubscription link", result: result }

    else
      Rails.logger.error "Unexpected CourseInterest.confirm_unsubscription result: #{result.inspect} for interest ##{interest.id}"
      { status: :error, message: "Something went wrong", result: result }
    end

  rescue StandardError => e
    Rails.logger.error "CourseInterestService.confirm_unsubscription failed for interest ##{interest&.id}: #{e.class} - #{e.message}"
    { status: :error, message: "Something went wrong", result: nil }
  end

  def self.generate_subscription_token(interest, purpose)
    interest.signed_id(
      purpose: purpose,
      expires_in: COURSE_INTEREST_TOKEN_EXPIRY
    )
  end

  # Returns true if this request should be blocked (and no email sent).
  # Two independent gates, checked cheapest-first:
  #   1. per-IP window  - stops one actor spraying many different addresses
  #   2. per-email cooldown - stops rapid resends to a single address
  def self.rate_limited?(course:, email:, ip:, action_type:)
    if ip.present? &&
       !RateLimiter.within_limit?(ip_rate_limit_key(ip: ip, action_type: action_type),
                                  limit: IP_RATE_LIMIT, ttl: IP_RATE_LIMIT_WINDOW)
      Rails.logger.warn "CourseInterest IP rate limit hit for action=#{action_type}"
      return true
    end

    unless RateLimiter.allow_once?(email_rate_limit_key(course: course, email: email, action_type: action_type),
                                   ttl: EMAIL_RATE_LIMIT_DURATION)
      Rails.logger.info "CourseInterest email cooldown hit for action=#{action_type}, course=##{course.id}, " \
                        "email_hash=#{email_log_id(email)}"
      return true
    end

    false
  end

  def self.rate_limited_response
    { status: :error, message: RATE_LIMITED_MESSAGE, result: :rate_limited }
  end

  def self.email_rate_limit_key(course:, email:, action_type:)
    normalized = email.to_s.strip.downcase
    "course_interest:email:#{action_type}:#{course.id}:#{Digest::SHA256.hexdigest(normalized)}"
  end

  def self.ip_rate_limit_key(ip:, action_type:)
    "course_interest:ip:#{action_type}:#{ip}"
  end

  private_class_method :rate_limited?, :rate_limited_response, :email_rate_limit_key, :ip_rate_limit_key
end
