# frozen_string_literal: true

class ContentProviderMailer < ApplicationMailer
  include ActionView::Helpers::TextHelper

  def event_content_provider_notification(event, content_provider)
    return if content_provider.approval_notification_email.blank?

    @event = event
    @content_provider = content_provider

    mail(
      to: content_provider.approval_notification_email,
      subject: "New event ‘#{@event.title}’ submitted with your content provider ‘#{@content_provider.title}’"
    )
  end

  def course_content_provider_notification(course, content_provider)
    return if content_provider.approval_notification_email.blank?

    @course = course
    @content_provider = content_provider

    mail(
      to: content_provider.approval_notification_email,
      subject: "New course ‘#{@course.title}’ submitted for ‘#{@content_provider.title}’"
    )
  end
end
