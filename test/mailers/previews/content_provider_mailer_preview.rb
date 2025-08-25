# frozen_string_literal: true
# Preview all emails at http://localhost:3000/rails/mailers/content_provider_mailer

class ContentProviderMailerPreview < ActionMailer::Preview

  def notify_content_provider
    @event = Event.first
    @content_provider = @event&.content_providers&.first
    raise "No event or content provider found for preview" unless @event && @content_provider
    ContentProviderMailer.notify_content_provider(@event, @content_provider)
  end
end
