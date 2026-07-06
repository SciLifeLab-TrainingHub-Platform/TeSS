require "test_helper"

# Tests for trusted users creating events.
# Workflow:
# - Trusted user creates an event
# - Event is automatically approved
# - Event is immediately published and visible
# - Emails are sent to:
#   - The user (confirmation)
#   - The content provider
#   - Subscribed users interested in the course (if applicable)
# - Slack notification is sent
# - Visibility rules:
#   - All users and public can see the event

class TrustedUserFlowTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper
  include ActiveJob::TestHelper
  include Devise::Test::IntegrationHelpers

  setup do
    @trusted_user = users(:trusted_user)
    @regular_user = users(:regular_user)
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
      learning_objectives: @event_fixture.learning_objectives,
      description: @event_fixture.description,
      title: "Trusted user published event",
      url: @event_fixture.url,
      duration: @event_fixture.duration,
      recognition: @event_fixture.recognition,
      event_prices_attributes: [{ cost: 9.99, currency: "SEK", audience_type: "Academic" }]
    }
  end

  test "trusted user creates approved event and triggers notifications" do
    sign_in @trusted_user

    channels = ENV.fetch('SLACK_COURSE_NOTIFICATION_CHANNELS').split(',').map(&:strip)
    event = nil

    # Check job enqueue and emails
    perform_enqueued_jobs do

      assert_emails 2 do
        assert_enqueued_with(job: SlackNotificationJob) do
          event = @trusted_user.events.create!(@parameters)
        end
      end

      assert event.persisted?
      assert_equal "Trusted user published event", event.title
      assert_equal "approved", event.event_status
      assert_equal @trusted_user, event.user
    end

    # Inspect Slack job args separately if needed
    slack_job = enqueued_jobs.find { |j| j[:job] == SlackNotificationJob }
    if slack_job
      message_arg = slack_job[:args].first
      channels_arg = slack_job[:args].second

      assert_includes message_arg, "New #{event.class.name} Announcement from the"
      assert_equal channels, channels_arg
    end

    # Emails
    user_email = ActionMailer::Base.deliveries.find { |m| m.to.include?(@trusted_user.email) }
    provider_email = ActionMailer::Base.deliveries.find { |m| m.to.include?(@content_provider.approval_notification_email) }

    assert_not_nil user_email
    assert_match "Your event '#{event.title}' has been successfully published", user_email.subject

    assert_not_nil provider_email
    assert_match "New event ‘#{event.title}’ submitted with your content provider ‘#{@content_provider.title}’", provider_email.subject

    sign_out @trusted_user
  end

  test "approved event visibility for all users and public" do
    sign_in @trusted_user
    event = @trusted_user.events.create!(@parameters)
    sign_out @trusted_user

    assert_equal "approved", event.event_status

    # Public index
    get "/events", params: { format: :json }
    assert_response :success
    events_index = JSON.parse(response.body)
    assert_includes events_index.map { |e| e["id"] }, event.id

    # Public show
    get "/events/#{event.id}", params: { format: :json }
    assert_response :success
    event_show = JSON.parse(response.body)
    assert_equal event.id, event_show["id"]

    # Regular user
    sign_in @regular_user

    get "/events", params: { format: :json }
    events_index = JSON.parse(response.body)
    assert_includes events_index.map { |e| e["id"] }, event.id

    get "/events/#{event.id}", params: { format: :json }
    assert_response :success

    sign_out @regular_user
  end

  test "trusted user approved course event emails subscribed course interests" do
    sign_in @trusted_user

    course = courses(:approved_course)
    content_provider = content_providers(:goblet)
    course.content_providers << content_provider
    course.save!
    course.reload

    # these interest are status: :subscribed and should recieve email
    course_interest1 = CourseInterest.create!(
      course: course,
      email: "alice@example.com",
      status: :subscribed
    )

    course_interest2 = CourseInterest.create!(
      course: course,
      email: "bob@example.com",
      status: :subscribed
    )

    course_interest3 = CourseInterest.create!(
      course: course,
      user: @regular_user,
      status: :subscribed
    )

    # negative cases (should NOT receive emails)
    course_interest4 = CourseInterest.create!(
      course: course,
      email: "charlie@example.com",
      status: :pending_subscription
    )

    course_interest5 = CourseInterest.create!(
      course: course,
      email: "david@example.com",
      status: :pending_unsubscription
    )

    course_interest6 = CourseInterest.create!(
      course: course,
      user: users(:another_regular_user),
      status: :unsubscribed
    )

    perform_enqueued_jobs do
      @trusted_user.events.create!(
        @parameters.merge(
          course: course,
        )
      )
    end

    deliveries = ActionMailer::Base.deliveries

    expected_subject = "New training event for: #{course.title}"

    # should receive emails
    expected_recipients = [
      course_interest1.email,
      course_interest2.email,
      course_interest3.user.email
    ]

    expected_recipients.each do |email|
      mail = deliveries.find { |m| m.to.include?(email) }
      assert_not_nil mail, "Expected email for #{email}"
      assert_equal expected_subject, mail.subject
    end

    # should NOT receive emails
    negative_recipients = [
      course_interest4.email,
      course_interest5.email,
      course_interest6.user.email
    ]
    negative_recipients.each do |email|
      refute deliveries.any? { |m| m.to.include?(email) },
             "Unexpected email received for #{email} (this recipient should not have been notified)"
    end
    sign_out @trusted_user
  end

  test "approved event without course does not send course interest emails" do
    sign_in @trusted_user

    course = courses(:approved_course)
    content_provider = content_providers(:goblet)

    course.content_providers << content_provider
    course.save!

    CourseInterest.create!(
      course: course,
      email: "alice@example.com",
      status: :subscribed
    )

    CourseInterest.create!(
      course: course,
      email: "bob@example.com",
      status: :subscribed
    )

    perform_enqueued_jobs do
      @trusted_user.events.create!(
        @parameters.merge(course: nil)
      )
    end

    deliveries = ActionMailer::Base.deliveries

    refute deliveries.any? { |m|
      m.to.include?("alice@example.com") &&
        m.subject == "New training event for: #{course.title}"
    }, "Unexpected course interest email received for alice@example.com (event had no course)"

    refute deliveries.any? { |m|
      m.to.include?("bob@example.com") &&
        m.subject == "New training event for: #{course.title}"
    }, "Unexpected course interest email received for bob@example.com (event had no course)"
  end
end
