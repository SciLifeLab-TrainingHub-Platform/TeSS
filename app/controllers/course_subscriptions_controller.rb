class CourseSubscriptionsController < ApplicationController

  skip_before_action :authenticate_user!, :authenticate_user_from_token!,
                     only: [:request_email_action, :confirm_subscription, :confirm_unsubscribe]

  def request_email_action
    course = Course.friendly.find(params[:course_id])
    if current_user
      return redirect_to root_path,
                         alert: "Logged-in users should manage subscriptions through their account."
    end

    result =
      case params[:action_type]
      when CourseInterest::ACTION_REQUEST_SUBSCRIBE
        CourseInterestService.request_subscription(
          course: course,
          email: params[:email]
        )

      when CourseInterest::ACTION_REQUEST_UNSUBSCRIBE
        CourseInterestService.request_unsubscription(
          course: course,
          email: params[:email]
        )

      else
        return redirect_to course_path(course), alert: "Invalid action"
      end

    if result[:status] == :error
      redirect_to course_path(course), alert: result[:message]
    else
      redirect_to course_path(course), notice: result[:message]
    end

  rescue ActiveRecord::RecordNotFound
    redirect_to courses_path, alert: "Course not found"

  rescue StandardError
    redirect_to course_path(course), alert: "Something went wrong. Please try again."
  end

  def confirm_subscription
    course = Course.friendly.find(params[:course_id])
    token = params[:token]

    interest = CourseInterest.find_signed!(
      token,
      purpose: CourseInterest::TOKEN_PURPOSE_SUBSCRIPTION
    )

    # safety check (token might belong to another course/email)
    unless interest.course_id == course.id
      return redirect_to course_path(course), alert: "Invalid confirmation link"
    end

    result = CourseInterestService.confirm_subscription(interest)

    case result
    when CourseInterest::RESULT_SUBSCRIBED
      redirect_to course_path(course), notice: "Subscription confirmed successfully"
    when CourseInterest::RESULT_ALREADY_SUBSCRIBED
      redirect_to course_path(course), notice: "You are already subscribed"
    else
      redirect_to course_path(course), alert: "Something went wrong. Please try again."
    end

  rescue ActiveSupport::MessageVerifier::InvalidSignature
    redirect_to course_path(course), alert: "Invalid or expired confirmation link"

  rescue ActiveRecord::RecordNotFound
    redirect_to courses_path, alert: "Course not found"

  rescue StandardError => e
    pp "error im adsasd"
    pp e
    redirect_to course_path(course), alert: "Something went wrong. Please try again."
  end

  def confirm_unsubscribe

    pp "in 123 confirm_unsubscribe"
  end
end