# Preview all emails at http://localhost:3000/rails/mailers/admin_mailer/
class AdminMailerPreview < ActionMailer::Preview

  def review_event
    @event = Event.first
    AdminMailer.review_event(@event)
  end

  def event_updated_by_user
    @event = Event.first
    AdminMailer.event_updated_by_user(@event)
  end
end
