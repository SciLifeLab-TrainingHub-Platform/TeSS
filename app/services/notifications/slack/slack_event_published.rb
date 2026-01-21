# app/services/notifications/slack_event_published.rb
module Notifications

  module Slack
    class SlackEventPublished
      def initialize(record)
        @record = record
      end

      def call
        SlackNotificationJob.perform_later(message, channels)
      end

      private

      attr_reader :event

      # Build the Slack message
      def message
        <<~MESSAGE
          New #{@record.class.name} Announcement from the <#{root_url}|Training Portal>

          > :scilife: *#{@record.title}*
          > <#{record_url}|More information>
        MESSAGE
      end

      # Slack channels to notify
      # we can also add channels depending on type i.e. Event or Course
      def channels
        ENV.fetch('SLACK_COURSE_NOTIFICATION_CHANNELS')
           .split(',')
           .map(&:strip)
      end

      # Helpers for URLs
      def root_url
        Rails.application.routes.url_helpers.root_url
      end

      def record_url
        case @record
        when Event then Rails.application.routes.url_helpers.event_url(@record)
        when Course then Rails.application.routes.url_helpers.course_url(@record)
        else
          raise "Unsupported record type for SlackPublished: #{@record.class.name}"
        end
      end
    end
  end
end
