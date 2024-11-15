# Preview all emails at http://localhost:3000/rails/mailers/user_mailer
class UserMailerPreview < ActionMailer::Preview

  def event_published
    @event = Event.first
    UserMailer.event_published(@event)
  end
end
