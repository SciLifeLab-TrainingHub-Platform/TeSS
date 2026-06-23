# frozen_string_literal: true

class CourseInterestService

  COURSE_INTEREST_TOKEN_EXPIRY = 7.days

  # tested
  def self.subscribe_user!(course:, user:)
    result = CourseInterest.subscribe!(
      course: course,
      user: user
    )

    case result
    when CourseInterest::RESULT_SUBSCRIBED
      {
        status: :ok,
        message: "You have subscribed successfully",
        result: result
      }
    when CourseInterest::RESULT_ALREADY_SUBSCRIBED
      {
        status: :ok,
        message: "You are already subscribed",
        result: result
      }
    when CourseInterest::RESULT_INVALID
      {
        status: :error,
        message: "Invalid request",
        result: result
      }
    else
      {
        status: :error,
        message: "Something went wrong",
        result: result
      }
    end
  end

  # tested
  def self.unsubscribe_user!(course:, user:)
    result = CourseInterest.unsubscribe!(
      course: course,
      user: user
    )

    case result
    when CourseInterest::RESULT_UNSUBSCRIBED
      {
        status: :ok,
        message: "You have unsubscribed successfully",
        result: result
      }
    when CourseInterest::RESULT_NOT_SUBSCRIBED
      {
        status: :ok,
        message: "You are not currently subscribed",
        result: result
      }
    when CourseInterest::RESULT_INVALID
      {
        status: :error,
        message: "Invalid request",
        result: result
      }
    else
      {
        status: :error,
        message: "Something went wrong",
        result: result
      }
    end
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
      {
        status: :ok,
        message: "Subscription confirmation email sent",
        result: result
      }
    when CourseInterest::RESULT_ALREADY_SUBSCRIBED
      {
        status: :ok,
        message: "You are already subscribed",
        result: result
      }
    when CourseInterest::RESULT_INVALID
      {
        status: :error,
        message: "Invalid request",
        result: result
      }
    else
      {
        status: :error,
        message: "Something went wrong",
        result: result
      }
    end
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

      {
        status: :ok,
        message: "Unsubscription confirmation email sent",
        result: result
      }

    when CourseInterest::RESULT_NOT_SUBSCRIBED
      {
        status: :ok,
        message: "You are not currently subscribed",
        result: result
      }

    when CourseInterest::RESULT_INVALID
      {
        status: :error,
        message: "Invalid request",
        result: result
      }

    else
      {
        status: :error,
        message: "Something went wrong",
        result: result
      }
    end
  end

  def self.confirm_subscription!(interest:)
    result = CourseInterest.confirm_subscription(interest)

    case result
    when CourseInterest::RESULT_SUBSCRIBED
      {
        status: :ok,
        message: "Subscription confirmed successfully",
        result: result
      }

    when CourseInterest::RESULT_ALREADY_SUBSCRIBED
      {
        status: :ok,
        message: "You are already subscribed",
        result: result
      }

    when CourseInterest::RESULT_INVALID
      {
        status: :error,
        message: "Invalid subscription link",
        result: result
      }

    else
      {
        status: :error,
        message: "Something went wrong",
        result: result
      }
    end
  end

  def self.confirm_unsubscription(interest)
    result = CourseInterest.confirm_unsubscription(interest)

    case result
    when CourseInterest::RESULT_UNSUBSCRIBED
      {
        status: :ok,
        message: "You have been unsubscribed successfully",
        result: result
      }

    when CourseInterest::RESULT_ALREADY_UNSUBSCRIBED
      {
        status: :ok,
        message: "This course is already unsubscribed for the email provided.",
        result: result
      }

    when CourseInterest::RESULT_NOT_SUBSCRIBED
      {
        status: :ok,
        message: "Course subscription not found",
        result: result
      }

    when CourseInterest::RESULT_INVALID
      {
        status: :error,
        message: "Invalid unsubscription link",
        result: result
      }

    else
      {
        status: :error,
        message: "Something went wrong",
        result: result
      }
    end
  end

  def self.generate_subscription_token(interest, purpose)
    interest.signed_id(
      purpose: purpose,
      expires_in: COURSE_INTEREST_TOKEN_EXPIRY
    )
  end
end
