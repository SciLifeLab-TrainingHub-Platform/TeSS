# frozen_string_literal: true

module Notifications
  class EventNotifier
    def initialize(event)
      @event = event
    end

    def publish
      # event publishing email
      UserMailer.event_published(@event).deliver_later
      # content providers notification email
      @event.content_providers&.each do |cp|
        ContentProviderMailer.event_content_provider_notification(@event, cp).deliver_later
      end
      # course interest email to all subscribers
      if @event.course.present?
        emails = CourseInterest.find_all_subscribed_emails(@event.course)
        emails.each do |email|
          CourseInterestMailer.announce_event(@event, email).deliver_later
        end
      end
        # event publishing message on slack
      Notifications::Slack::SlackEventPublished.new(@event).call
    end

    def review
      AdminMailer.review_event(@event).deliver_later
      UserMailer.event_submitted(@event).deliver_later
    end

    def reset_status_and_notify_admin(current_user)
      return unless @event.event_status == Event.event_statuses.key(Event.event_statuses[:revisions_required])
      return unless @event.user_id == current_user.id

      @event.update_column(:event_status, Event.event_statuses[:awaiting_review])
      AdminMailer.event_updated_by_user(@event).deliver_later
    end
  end
end
