# Preview all emails at http://localhost:3000/rails/mailers/admin_mailer/review_event
class AdminMailerPreview < ActionMailer::Preview

  def review_event
    @event = Event.first
    AdminMailer.review_event(@event)
  end
end