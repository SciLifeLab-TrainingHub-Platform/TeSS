class SlackNotificationJob < ApplicationJob
  queue_as :slack_notifications

  def perform(message, channels)
    unless Rails.env.production?
      Rails.logger.info("Slack notification skipped: Not in production environment")
      return
    end

    client = Slack::Web::Client.new
    channels.each do |channel|
      begin
        client.chat_postMessage(channel: channel, text: message, as_user: true, unfurl_links: false)
        Rails.logger.info("Slack notification sent successfully to '#{channel}'")
      rescue Slack::Web::Api::Errors::SlackError => e
        Rails.logger.error("Slack notification failed for '#{channel}': #{e.message}")
      end
    end
  end
end
