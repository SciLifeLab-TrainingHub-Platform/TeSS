class AdminMailer < ApplicationMailer

  ADMIN_EMAIL_ADDRESS = 'traininghub@scilifelab.se'.freeze

  def review_event(event)
    @event = event
    mail(to: ADMIN_EMAIL_ADDRESS, subject: "Event review for #{@event.title}")
  end

  def event_updated_by_user(event)
    @event = event
    mail(to: ADMIN_EMAIL_ADDRESS, subject: "Event #{@event.title} updated by #{@event.user.username}")
  end
end
