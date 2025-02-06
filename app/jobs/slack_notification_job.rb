class SlackNotificationJob < ApplicationJob
  queue_as :slack_notifications

  # List of allowed channels
  ALLOWED_CHANNELS = %w[#traininghub-dev #scilifelab-events #training].freeze

  def perform(message, channels)

    unless Rails.env.production?
      Rails.logger.info("Slack notification skipped: Not in production environment")
      return
    end

    # Check if the provided channel is allowed
    channels = Array(channels)
    unauthorized_channels = channels - ALLOWED_CHANNELS
    if unauthorized_channels.any?
      Rails.logger.error("Slack notification failed: Unauthorized channels #{unauthorized_channels.join(', ')}")
      return
    end

    client = Slack::Web::Client.new
    channels.each do |channel|
      begin
        client.chat_postMessage(channel: channel, text: message, as_user: true)
        Rails.logger.info("Slack notification sent successfully to '#{channel}'")
      rescue Slack::Web::Api::Errors::SlackError => e
        Rails.logger.error("Slack notification failed for '#{channel}': #{e.message}")
      end
    end
  end
end
