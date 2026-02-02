class UserMailer < ApplicationMailer
  def event_published(event)
    @event = event
    mail(to: @event.user.email, subject: "Your event '#{@event.title}' has been successfully published")
  end

  def event_submitted(event)
    @event = event
    mail(to: @event.user.email, subject: "Your event '#{@event.title}' has been successfully submitted")
  end

  def course_published(course)
    @course = course
    mail(to: @course.user.email, subject: "Your course '#{@course.title}' has been successfully published")
  end

  def course_submitted(course)
    @course = course
    mail(to: @course.user.email, subject: "Your course '#{@course.title}' has been successfully submitted")
  end
end
