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

  test "should not send notifications in non production environment" do
    Rails.stub(:env, ActiveSupport::StringInquirer.new("development")) do
      SlackNotificationJob.perform_now("Test message", ["#test-channel"])
      assert_match(/Slack notification skipped: Not in production environment/, @log_output.string)
    end
  end

  test 'job enqueues correctly with valid channels' do
    message = 'Test message'
    channels = ['#traininghub-dev']

    assert_enqueued_with(job: SlackNotificationJob, args: [message, channels]) do
      SlackNotificationJob.perform_later(message, channels)
    end
  end

  test "should log errors for failed notifications" do
    Rails.stub(:env, ActiveSupport::StringInquirer.new("production")) do
      SlackNotificationJob.perform_now("Test message", ["#channel1"])
      assert_match(/Slack notification failed for '#channel1'/, @log_output.string)
    end
  end
end
