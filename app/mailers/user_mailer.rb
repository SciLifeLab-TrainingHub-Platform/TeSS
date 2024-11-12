class UserMailer < ApplicationMailer
  def event_published(event)
    @event = event
    mail(to: @event.user.email, subject: 'Event published')
  end
end
