# app/mailers/course_interest_mailer.rb
class CourseInterestMailer < ApplicationMailer
  helper ApplicationHelper

  def announce_event(event, email, token)
    @event = event
    @course = event.course
    @confirmation_cancellation_url = confirm_course_unsubscription_course_subscription_url(
      @course,
      token: token
    )
    mail(to: email, subject: "New training event for: #{@course.title}")
  end
end
