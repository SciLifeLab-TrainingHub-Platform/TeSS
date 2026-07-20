# frozen_string_literal: true

class CourseInterestService

  COURSE_INTEREST_TOKEN_EXPIRY = 7.days
  GENERIC_SUBSCRIBE_MESSAGE = "If that email isn't already subscribed, we've sent a confirmation link."

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

  def self.request_subscription!(course:, email:)
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

  def self.request_unsubscription!(course:, email:)
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
end
