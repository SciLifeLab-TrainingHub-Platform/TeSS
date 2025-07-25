class UserMailer < ApplicationMailer
  def event_published(event)
    pp "event publish email sent"
    @event = event
    mail(to: @event.user.email, subject: "Your event '#{@event.title}' has been successfully published")
  end

  def event_submitted(event)
    pp "event submitted email sent"
    @event = event
    mail(to: @event.user.email, subject: "Your event '#{@event.title}' has been successfully submitted")
  end

  def notify_content_provider(event, content_provider)
    return if content_provider.approval_notification_email.blank?
    pp "notify_content_provider email sent"
    pp "content provider #{content_provider.title} has been successfully notified"

    @event = event
    @content_provider = content_provider

    mail(
      to: content_provider.approval_notification_email,
      subject: "New event ‘#{@event.title}’ submitted with your content provider ‘#{@content_provider.title}’"
    )
  end
end
