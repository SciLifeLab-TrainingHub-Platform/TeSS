require "test_helper"

class SlackNotificationJobTest < ActiveJob::TestCase
  def setup
    # Backup the original logger and set up a mock logger
    @original_logger = Rails.logger
    @log_output = StringIO.new
    Rails.logger = ActiveSupport::Logger.new(@log_output)
  end

  def teardown
    # Restore the original logger
    Rails.logger = @original_logger
  end


  test 'job enqueues correctly with valid channels' do
    message = 'Test message'
    channels = ['#traininghub-dev']

    assert_enqueued_with(job: SlackNotificationJob, args: [message, channels]) do
      SlackNotificationJob.perform_later(message, channels)
    end
  end

  test 'job skips unauthorized channels' do
    Rails.stub(:env, ActiveSupport::StringInquirer.new('production')) do
      message = 'Test message'
      unauthorized_channels = ['#unauthorized-channel']

      assert_no_enqueued_jobs only: SlackNotificationJob do
        SlackNotificationJob.perform_now(message, unauthorized_channels)
      end
      assert_match(/Slack notification failed: Unauthorized channels #unauthorized-channel/, @log_output.string)
    end
  end
end
