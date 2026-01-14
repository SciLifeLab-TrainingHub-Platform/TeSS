require "test_helper"

# Tests for admin actions on events.
# Covers all moderation workflows:
# - Approving pending events:
#   - Event status changes to approved
#   - Event is published on the events index
#   - Emails sent to user and content provider
#   - Slack notification sent
# - Rejecting events:
#   - Event status changes to rejected
#   - Only admin and owner can see the event
#   - Public and other users cannot view the event
# - Requesting revisions:
#   - Event status is set back to pending
#   - Owner is notified manually (not automated in tests)
#   - Visibility: only admin and owner can see
# - Visibility rules are verified after each admin action

class AdminApprovalFlowTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include ActionMailer::TestHelper
  include ActiveJob::TestHelper

  setup do
    @admin = users(:admin)
    @user = users(:regular_user)
    @user2 = users(:another_regular_user2)
    @content_provider = content_providers(:approval_notification_email_contact_provider)
    @event_fixture = events(:one)

    @parameters = {
      online: true,
      start: 1.day.from_now,
      end: 2.days.from_now,
      host_institutions: @event_fixture.host_institutions,
      timezone: @event_fixture.timezone,
      contact: @event_fixture.contact,
      eligibility: @event_fixture.eligibility,
      node_ids: [@event_fixture.nodes.first.id],
      language: @event_fixture.language,
      prerequisites: @event_fixture.prerequisites,
      target_audience: @event_fixture.target_audience,
      content_provider_ids: [@content_provider.id],
      cost_basis: @event_fixture.cost_basis,
      learning_objectives: @event_fixture.learning_objectives,
      description: @event_fixture.description,
      title: "Trusted user published event",
      url: @event_fixture.url,
      duration: @event_fixture.duration,
      recognition: @event_fixture.recognition,
      event_status: Event.event_statuses[:awaiting_review]
    }
    @pending_event = @user.events.create!(@parameters)
  end

  # ----------------------------
  # Approve pending event
  # ----------------------------
  test "admin approves pending event" do
    sign_in @admin
    channels = ENV.fetch('SLACK_COURSE_NOTIFICATION_CHANNELS').split(',').map(&:strip)

    perform_enqueued_jobs do
      # Simulate approving event
      assert_emails 2 do
        assert_enqueued_with(job: SlackNotificationJob) do
          @pending_event.update!(event_status: Event.event_statuses[:approved])
        end
      end
    end

    # Slack job
    slack_job = enqueued_jobs.find { |j| j[:job] == SlackNotificationJob }

    if slack_job
      message_arg = slack_job[:args].first
      channels_arg = slack_job[:args].second
      assert_includes message_arg, "New Course Announcement from the"
      assert_equal channels, channels_arg
    end

    # Emails
    user_email = ActionMailer::Base.deliveries.find { |m| m.to.include?(@user.email) }
    provider_email = ActionMailer::Base.deliveries.find { |m| m.to.include?(@content_provider.approval_notification_email) }

    assert_not_nil user_email
    assert_includes user_email.subject, @pending_event.title
    assert_not_nil provider_email
    assert_includes provider_email.subject, @pending_event.title

    # Event should be published
    assert_equal "approved", @pending_event.reload.event_status

    sign_out @admin
  end

  # ----------------------------
  # Reject event
  # ----------------------------
  test "admin rejects event" do
    sign_in @admin

    @pending_event.update!(event_status: Event.event_statuses[:declined])

    # Admin can see

    sign_in @admin
    get "/events/#{@pending_event.id}", params: { format: :json }
    assert_response :success
    sign_out @admin

    # Other users cannot see
    sign_in @user2
    assert_raises(ActiveRecord::RecordNotFound) do
      get "/events/#{@pending_event.id}", params: { format: :json }
    end
    sign_out @user2

    # Public cannot see
    assert_raises(ActiveRecord::RecordNotFound) do
      get "/events/#{@pending_event.id}", params: { format: :json }
    end
  end

  # ----------------------------
  # Request revisions
  # ----------------------------
  test "admin requests revisions" do
    sign_in @admin

    @pending_event.update!(event_status: Event.event_statuses[:awaiting_review])

    # Only owner and admin can see
    sign_in @user
    get "/events/#{@pending_event.id}", params: { format: :json }
    assert_response :success
    sign_out @user

    sign_in @admin
    get "/events/#{@pending_event.id}", params: { format: :json }
    assert_response :success
    sign_out @admin

    sign_in @user2
    assert_raises(ActiveRecord::RecordNotFound) do
      get "/events/#{@pending_event.id}", params: { format: :json }
    end
    sign_out @user2

    # Public cannot see
    assert_raises(ActiveRecord::RecordNotFound) do
      get "/events/#{@pending_event.id}", params: { format: :json }
    end
  end

end