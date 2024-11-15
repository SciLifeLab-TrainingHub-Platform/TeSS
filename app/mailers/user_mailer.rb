class UserMailer < ApplicationMailer
  def event_published(event)
    @event = event
    mail(to: @event.user.email, subject: "Your event '#{@event.title}' has been successfully published")
  end
end
