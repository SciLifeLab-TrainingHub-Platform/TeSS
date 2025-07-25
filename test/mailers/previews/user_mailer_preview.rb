# Preview all emails at http://localhost:3000/rails/mailers/user_mailer
class UserMailerPreview < ActionMailer::Preview

  def event_published
    @event = Event.first
    UserMailer.event_published(@event)
  end

  def event_submitted
    @event = Event.first
    UserMailer.event_submitted(@event)
  end

  def notify_content_provider
    @event = Event.first
    @content_provider = @event&.content_providers&.first
    raise "No event or content provider found for preview" unless @event && @content_provider
    UserMailer.notify_content_provider(@event, @content_provider)
  end
end
