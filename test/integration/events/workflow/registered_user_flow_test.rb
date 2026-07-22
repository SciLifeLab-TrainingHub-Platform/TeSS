require "test_helper"

# Tests for registered (non-trusted) users creating events.
# This includes the full workflow for a registered user:
# - Creating a new event below the EVENT_APPROVAL_THRESHOLD
# - Event is set to pending approval
# - Emails are sent to the admin notifying them of the pending event
# - Emails are sent to the user confirming their event is pending
# - Visibility rules for pending events:
#   - Only the event owner and admin can see the event
#   - Other users and the public cannot view the event in index or show pages
# - Updating an event in "revisions_required" state by the owner:
#   - Status is reset to awaiting_review
#   - Admin is notified that the event was updated

class RegisteredUserFlowTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper
  include ActiveJob::TestHelper
  include Devise::Test::IntegrationHelpers

  setup do
    @user = users(:regular_user)
    @user2 = users(:another_regular_user2)
    @admin = users(:admin)
    @event = events(:one)

    @node = nodes(:westeros)
    @content_providers = content_providers(:goblet)

    @parameters = { online: true, start: @event.start, end: @event.end,
                    host_institutions: @event.host_institutions, timezone: @event.timezone,
                    contact: @event.contact, eligibility: @event.eligibility,
                    node_ids: [@event.nodes[0].id], language: @event.language,
                    prerequisites: @event.prerequisites, target_audience: @event.target_audience,
                    content_provider_ids: [@event.content_providers[0].id],
                    learning_objectives: @event.learning_objectives,
                    description: @event.description,
                    title: "this is the title",
                    url: @event.url,
                    duration: @event.duration,
                    recognition: @event.recognition,
                    event_status: Event.event_statuses[:awaiting_review],
                    event_prices_attributes: [{ cost: 9.99, currency: "SEK", audience_type: "Academic" }] }
  end

  test "registered user creates pending event and triggers emails" do
    # Log in user
    sign_in @user

    perform_enqueued_jobs do
      # Go to new event page
      get '/events/new'
      assert_response :success

      # Define variable outside the block so we can use it later
      event = nil

      # Ensure 2 emails are sent (Admin + User)
      assert_emails 2 do
        event = @user.events.create!(@parameters)

        assert event.persisted?
        assert_equal "this is the title", event.title
        assert_equal "awaiting_review", event.event_status
        assert_equal @user, event.user
      end

      admin_email = ActionMailer::Base.deliveries.find { |m| m.to.include?(AdminMailer::ADMIN_EMAIL_ADDRESS) }
      user_email = ActionMailer::Base.deliveries.find { |m| m.to.include?(@user.email) }

      assert_not_nil admin_email
      assert_match "Event review for #{event.title}", admin_email.subject

      assert_not_nil user_email
      assert_match "Your event '#{event.title}' has been successfully submitted", user_email.subject
    end
  end

  test "pending event visibility" do
    # user 1
    sign_in @user

    get '/events/new'
    assert_response :success

    event = @user.events.create!(@parameters)

    assert event.persisted?
    assert_equal "this is the title", event.title
    assert_equal "awaiting_review", event.event_status
    assert_equal @user, event.user

    # Index page
    get '/events', params: { format: :json }
    assert_response :success
    events_index = JSON.parse(response.body)
    assert_includes events_index.map { |e| e["id"] }, event.id

    # Show page
    get "/events/#{event.id}", params: { format: :json }
    assert_response :success
    event_show = JSON.parse(response.body)
    assert_equal event.id, event_show["id"]

    sign_out @user

    # user 2
    sign_in @user2

    # Index page
    get '/events', params: { format: :json }
    assert_response :success
    events_index = JSON.parse(response.body)
    if TeSS::Config.solr_enabled
      refute_includes events_index.map { |e| e["id"] }, event.id
    end

    # Show page
    assert_raises(ActiveRecord::RecordNotFound) do
      get "/events/#{event.id}", params: { format: :json }
    end

    sign_out @user2

    # admin
    sign_in @admin

    # Index page
    get '/events', params: { format: :json }
    assert_response :success
    events_index = JSON.parse(response.body)
    assert_includes events_index.map { |e| e["id"] }, event.id

    # Show page
    get "/events/#{event.id}", params: { format: :json }
    assert_response :success
    event_show = JSON.parse(response.body)
    assert_equal event.id, event_show["id"]

    sign_out @admin
  end
  test "owner updating revisions_required event resets status and notifies admin" do
    sign_in @user
    event = @user.events.create!(@parameters)
    assert_equal "awaiting_review", event.event_status
    sign_out @user

    sign_in @admin
    event.update_column(:event_status, Event.event_statuses[:revisions_required])
    event.reload

    assert_equal "revisions_required", event.event_status
    sign_out @admin

    sign_in @user

    perform_enqueued_jobs do
      assert_emails 1 do
        patch event_path(event), params: { event: { title: "Updated after revisions" } }
      end
    end

    event.reload
    assert_equal "awaiting_review", event.event_status, "Event status should reset after owner update"

    admin_email = ActionMailer::Base.deliveries.find do |mail|
      mail.to.include?(AdminMailer::ADMIN_EMAIL_ADDRESS)
    end
    assert_not_nil admin_email, "Expected admin notification email"

    # Check email subject
    expected_subject = "Event #{event.title} updated by #{event.user.username}"
    assert_equal expected_subject, admin_email.subject

    # Verify email body contains key information
    assert_match "The event titled #{event.title} has been updated by #{event.user.username}", admin_email.body.encoded
    assert_match "The event status has been changed to Awaiting review", admin_email.body.encoded
  end
end
