class CourseSubscriptionMailer < ApplicationMailer

  def subscription_confirmation(email, course, token)
    @course = course
    @confirmation_url = confirm_subscription_course_subscription_url(
      course,
      token: token
    )
    @expires_in_days = (CourseInterestService::COURSE_INTEREST_TOKEN_EXPIRY / 1.day).to_i

    mail(
      to: email,
      subject: "Confirm your subscription for #{@course.title}"
    )
  end

  def unsubscription_confirmation(email, course, token)
    @course = course
    @confirmation_url = confirm_unsubscription_course_subscription_url(
      course,
      token: token
    )
    @expires_in_days = (CourseInterestService::COURSE_INTEREST_TOKEN_EXPIRY / 1.day).to_i

    mail(
      to: email,
      subject: "Confirm your unsubscription for #{@course.title}"
    )
    end
end
