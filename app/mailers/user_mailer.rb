class UserMailer < ApplicationMailer
  def event_published(event)
    @event = event
    mail(to: @event.user.email, subject: "Your event '#{@event.title}' has been successfully published")
  end

  def event_submitted(event)
    @event = event
    mail(to: @event.user.email, subject: "Your event '#{@event.title}' has been successfully submitted")
  end
end
