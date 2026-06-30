# app/mailers/course_interest_mailer.rb
class CourseInterestMailer < ApplicationMailer
  helper ApplicationHelper

  def announce_event(event, email)
    @event = event
    @course = event.course

    # Standard Rails mailer method to send the email
    mail(to: email, subject: "New training event for: #{@course.title}")
  end
end
