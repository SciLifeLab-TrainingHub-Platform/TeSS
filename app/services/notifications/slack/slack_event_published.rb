# app/services/notifications/slack_event_published.rb
module Notifications

  module Slack
    class SlackEventPublished
      def initialize(event)
        @event = event
      end

      def call
        return unless publishable?
        SlackNotificationJob.perform_later(message, channels)
      end

      private

      attr_reader :event

      def publishable?
        event.status_just_approved? && event.publishable?
      end

      # Build the Slack message
      def message
        <<~MESSAGE
          New Course Announcement from the <#{root_url}|Training Portal>

          > :scilife: *#{event.title}*
          > <#{event_url}|More information>
        MESSAGE
      end

      # Slack channels to notify
      def channels
        ENV.fetch('SLACK_COURSE_NOTIFICATION_CHANNELS')
           .split(',')
           .map(&:strip)
      end

      # Helpers for URLs
      def root_url
        Rails.application.routes.url_helpers.root_url
      end

      def event_url
        Rails.application.routes.url_helpers.event_url(event)
      end
    end
  end
end