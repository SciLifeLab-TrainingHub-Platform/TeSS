# frozen_string_literal: true

class ContentProviderMailer < ApplicationMailer
  include ActionView::Helpers::TextHelper

  def notify_content_provider(event, content_provider)
    return if content_provider.approval_notification_email.blank?

    @event = event
    @content_provider = content_provider

    mail(
      to: content_provider.approval_notification_email,
      subject: "New event ‘#{@event.title}’ submitted with your content provider ‘#{@content_provider.title}’"
    )
  end
end
