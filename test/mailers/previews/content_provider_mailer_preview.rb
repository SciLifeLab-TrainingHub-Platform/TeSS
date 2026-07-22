# frozen_string_literal: true
# Preview all emails at http://localhost:3000/rails/mailers/content_provider_mailer

class ContentProviderMailerPreview < ActionMailer::Preview

  def event_content_provider_notification
    @event = Event.first
    @content_provider = @event&.content_providers&.first
    raise 'No event or content provider found for preview' unless @event && @content_provider
    ContentProviderMailer.event_content_provider_notification(@event, @content_provider)
  end

  def course_content_provider_notification
    @course = Course.first
    @content_provider = @course&.content_providers&.first

    ContentProviderMailer.course_content_provider_notification(@course, @content_provider)
  end
end
