require 'test_helper'

# Tests for automatic user promotion to trusted role based on approved events.
# Covers:
# - User reaches EVENT_APPROVAL_THRESHOLD for approved events
# - User is automatically promoted to the trusted role
# - Future events created by the promoted user are auto-approved
# - Verification that users below the threshold are not prematurely promoted
# - Ensures database reflects the correct role for the user
# - Ensures workflow behavior changes after promotion (trusted user flow applies)

class UserRolePromotionTest < ActionDispatch::IntegrationTest

  include Devise::Test::IntegrationHelpers
  include ActionMailer::TestHelper
  include ActiveJob::TestHelper

  setup do
    @user = users(:regular_user)
    @user2 = users(:another_regular_user2)
    @admin = users(:admin)
    @content_provider = content_providers(:approval_notification_email_contact_provider)
    @event_fixture = events(:one)
    @trusted_user_role = roles(:trusted_user)
    @user_role = roles(:user)

    @event_params = {
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
      title: 'Trusted user published event',
      url: @event_fixture.url,
      duration: @event_fixture.duration,
      recognition: @event_fixture.recognition,
      event_status: Event::event_statuses[:awaiting_review],
      event_prices_attributes: [{ cost: 9.99, currency: 'SEK', audience_type: 'Academic' }]
    }

    @threshold = User::EVENT_APPROVAL_THRESHOLD
  end

  test 'user is promoted to trusted after reaching event approval threshold' do
    sign_in @admin

    perform_enqueued_jobs do
      (@threshold + 1).times do |i|
        event = @user.events.create!(@event_params.merge(title: "Approved Event #{i+1}"))
        event.update!(event_status: Event.event_statuses[:approved])
      end
    end

    # Reload user and check role
    @user.reload
    assert_equal @trusted_user_role.name, @user.role.name, 'User should be promoted to trusted after threshold approvals'
  end

  test 'future events by promoted user are automatically approved' do
    sign_in @admin

    (@threshold + 1).times do |i|
      event = @user.events.create!(@event_params.merge(title: "Approved Event #{i+1}"))
      event.update!(event_status: Event.event_statuses[:approved])
    end

    @user.reload
    assert_equal @trusted_user_role.name, @user.role.name

    sign_in @user
    perform_enqueued_jobs do
      new_event = @user.events.create!(@event_params.merge(title: 'Future Event Auto-Approved'))
      assert_equal Event.event_statuses.key(Event.event_statuses[:approved]), new_event.event_status
    end
  end

  test 'user below threshold is not promoted' do
    sign_in @admin
    (@threshold - 1).times do |i|
      event = @user2.events.create!(@event_params.merge(title: "Approved Event #{i+1}"))
      event.update!(event_status: 'approved')
    end
    @user2.reload
    assert_equal @user_role.name, @user2.role.name, 'User should not be promoted before reaching threshold'
  end

  test 'database reflects correct roles after promotion and non-promotion' do
    sign_in @admin
    (@threshold + 1).times do |i|
      event = @user.events.create!(@event_params.merge(title: "Approved Event #{i+1}"))
      event.update!(event_status: 'approved')
    end

    # @user2 still below threshold
    (@threshold - 1).times do |i|
      event = @user2.events.create!(@event_params.merge(title: "Approved Event #{i+1}"))
      event.update!(event_status: 'approved')
    end

    @user.reload
    @user2.reload

    assert_equal @trusted_user_role.name, @user.role.name
    assert_equal @user_role.name, @user2.role.name
  end
end
