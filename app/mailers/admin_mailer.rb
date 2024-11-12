class AdminMailer < ApplicationMailer

  ADMIN_EMAIL_ADDRESS = 'traininghub@scilifelab.se'.freeze

  def review_event(event)
    @event = event
    mail(to: ADMIN_EMAIL_ADDRESS, subject: 'Event review for ' + @event.title)
  end
end
