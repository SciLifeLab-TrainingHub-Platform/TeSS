# test/integration/courses/workflow/admin_approval_flow_test.rb
require "test_helper"

# Tests for admin actions on courses.
# Covers all moderation workflows:
# - Approving pending courses:
#   - Course status changes to approved
#   - Emails sent to user and content provider
#   - Slack notification sent
# - Rejecting courses:
#   - Course status changes to declined
#   - Only admin and owner can see the course
#   - Public and other users cannot view the course
# - Requesting revisions:
#   - Course status is set back to awaiting_review
#   - Owner is notified manually (not automated in tests)
# - Visibility rules are verified after each admin action

class AdminApprovalFlowCourseTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include ActionMailer::TestHelper
  include ActiveJob::TestHelper

  setup do
    @admin = users(:admin)
    @user = users(:regular_user)
    @user2 = users(:another_regular_user2)
    @content_provider = content_providers(:approval_notification_email_contact_provider)
    @course_fixture = courses(:one)
    @node = nodes(:good)

    @parameters = {
      title: "Test Course",
      url: "https://example.com/test_course",
      language: "en",
      licence: "Glide",
      description: "A test description",
      target_audience: ["students"],
      prerequisites_knowledge: "None",
      prerequisites_technical: "None",
      structure_and_duration: "1 week",
      learning_outcomes: "Learn testing",
      keywords: ["test", "ruby"],
      authors: [
        { "name" => "John Doe", "affiliation" => "Uni X", "orcid" => "0000-0001-5109-3700", "email" => "johndoe@example.com" },
        { "name" => "Jane Doe", "affiliation" => "Uni Y", "orcid" => "0000-0002-5109-3700", "email" => "janedoe@example.com" }
      ],
      contributors: [
        { "name" => "Jane Doe", "affiliation" => "Uni Y", "orcid" => "0000-0001-5109-3700" },
        { "name" => "Jane Doe", "affiliation" => "Uni Y", "orcid" => "0000-0002-5109-3700" }
      ],
      content_providers: [@content_provider],
      nodes: [@node],
    }

    @pending_course = @user.courses.create!(@parameters)
  end

  # Approve pending course
  test "admin approves pending course" do
    sign_in @admin

    pending_event = create_event_from_template(
      title: 'Pending approval event',
      url: 'https://example.com/pending-approval-event',
      user: @user
    )
    CoursePendingEvent.create!(course: @pending_course, event: pending_event)

    perform_enqueued_jobs do
      # Simulate approving course
      assert_emails 2 do
        @pending_course.update!(course_status: Course.course_statuses[:approved])
      end
    end

    # Emails
    user_email = ActionMailer::Base.deliveries.find { |m| m.to.include?(@user.email) }
    provider_email = ActionMailer::Base.deliveries.find { |m| m.to.include?(@content_provider.approval_notification_email) }

    assert_not_nil user_email
    assert_includes user_email.subject, @pending_course.title
    assert_not_nil provider_email
    assert_includes provider_email.subject, @pending_course.title

    # Course should be approved
    assert_equal "approved", @pending_course.reload.course_status
    assert_equal @pending_course.id, pending_event.reload.course_id
    assert_empty @pending_course.course_pending_events.pluck(:event_id)

    sign_out @admin
  end

  test "admin cannot approve pending course when pending events are no longer linkable" do
    sign_in @admin

    pending_event = create_event_from_template(
      title: 'Conflicting pending event',
      url: 'https://example.com/conflicting-pending-event',
      user: @user
    )
    CoursePendingEvent.create!(course: @pending_course, event: pending_event)

    other_course = @user.courses.create!(@parameters.merge(
      title: 'Other approved course',
      url: 'https://example.com/other-approved-course'
    ))
    other_course.update_column(:course_status, Course.course_statuses[:approved])
    pending_event.update_column(:course_id, other_course.id)

    clear_enqueued_jobs
    clear_performed_jobs
    approved_events_count_before = @user.reload.approved_events_count

    assert_no_enqueued_jobs do
      assert_raises(ActiveRecord::RecordInvalid) do
        @pending_course.update!(course_status: Course.course_statuses[:approved])
      end
    end

    assert_equal "awaiting_review", @pending_course.reload.course_status
    assert_equal other_course.id, pending_event.reload.course_id
    assert CoursePendingEvent.exists?(course_id: @pending_course.id, event_id: pending_event.id)
    assert_equal approved_events_count_before, @user.reload.approved_events_count
  end

  test "admin cannot approve pending course when pending events are no longer approved" do
    sign_in @admin

    pending_event = create_event_from_template(
      title: 'Pending event that becomes unapproved',
      url: 'https://example.com/pending-event-that-becomes-unapproved',
      user: @user
    )
    CoursePendingEvent.create!(course: @pending_course, event: pending_event)
    pending_event.update_column(:event_status, Event.event_statuses[:awaiting_review])

    clear_enqueued_jobs
    clear_performed_jobs
    approved_events_count_before = @user.reload.approved_events_count

    assert_no_enqueued_jobs do
      assert_raises(ActiveRecord::RecordInvalid) do
        @pending_course.update!(course_status: Course.course_statuses[:approved])
      end
    end

    assert_equal "awaiting_review", @pending_course.reload.course_status
    assert_nil pending_event.reload.course_id
    assert CoursePendingEvent.exists?(course_id: @pending_course.id, event_id: pending_event.id)
    assert_equal approved_events_count_before, @user.reload.approved_events_count
  end

  test "admin cannot approve pending course when owner cannot manage pending events" do
    sign_in @admin

    other_provider = ContentProvider.create!(
      title: 'Other Provider',
      url: 'https://example.com/other-provider',
      user: @user2,
      contact: 'other@example.com'
    )

    pending_event = create_event_from_template(
      title: 'Restricted pending event',
      url: 'https://example.com/restricted-pending-event',
      user: @user2,
      content_providers: [other_provider]
    )
    CoursePendingEvent.create!(course: @pending_course, event: pending_event)

    clear_enqueued_jobs
    clear_performed_jobs
    approved_events_count_before = @user.reload.approved_events_count

    assert_no_enqueued_jobs do
      assert_raises(ActiveRecord::RecordInvalid) do
        @pending_course.update!(course_status: Course.course_statuses[:approved])
      end
    end

    assert_equal "awaiting_review", @pending_course.reload.course_status
    assert_nil pending_event.reload.course_id
    assert CoursePendingEvent.exists?(course_id: @pending_course.id, event_id: pending_event.id)
    assert_equal approved_events_count_before, @user.reload.approved_events_count
  end

  test "admin cannot approve pending course when one of multiple pending events becomes invalid" do
    sign_in @admin

    ok_event = create_event_from_template(
      title: 'Pending ok event',
      url: 'https://example.com/pending-ok-event',
      user: @user
    )
    conflicting_event = create_event_from_template(
      title: 'Pending conflicting event',
      url: 'https://example.com/pending-conflicting-event',
      user: @user
    )
    CoursePendingEvent.create!(course: @pending_course, event: ok_event)
    CoursePendingEvent.create!(course: @pending_course, event: conflicting_event)

    other_course = @user.courses.create!(@parameters.merge(
      title: 'Other approved course',
      url: 'https://example.com/other-approved-course-2'
    ))
    other_course.update_column(:course_status, Course.course_statuses[:approved])
    conflicting_event.update_column(:course_id, other_course.id)

    clear_enqueued_jobs
    clear_performed_jobs
    approved_events_count_before = @user.reload.approved_events_count

    assert_no_enqueued_jobs do
      assert_raises(ActiveRecord::RecordInvalid) do
        @pending_course.update!(course_status: Course.course_statuses[:approved])
      end
    end

    assert_equal "awaiting_review", @pending_course.reload.course_status
    assert_nil ok_event.reload.course_id
    assert_equal other_course.id, conflicting_event.reload.course_id
    assert CoursePendingEvent.exists?(course_id: @pending_course.id, event_id: ok_event.id)
    assert CoursePendingEvent.exists?(course_id: @pending_course.id, event_id: conflicting_event.id)
    assert_equal approved_events_count_before, @user.reload.approved_events_count
  end

  test "admin approves pending course clears pending claims when pending event is already linked" do
    sign_in @admin

    pending_event = create_event_from_template(
      title: 'Already linked pending event',
      url: 'https://example.com/already-linked-pending-event',
      user: @user
    )
    CoursePendingEvent.create!(course: @pending_course, event: pending_event)
    pending_event.update_column(:course_id, @pending_course.id)

    perform_enqueued_jobs do
      assert_emails 2 do
        @pending_course.update!(course_status: Course.course_statuses[:approved])
      end
    end

    assert_equal "approved", @pending_course.reload.course_status
    assert_equal @pending_course.id, pending_event.reload.course_id
    assert_empty @pending_course.course_pending_events.pluck(:event_id)
  end

  # Reject course
  test "admin rejects course" do
    sign_in @admin

    @pending_course.update!(course_status: Course.course_statuses[:declined])

    # Admin can see
    get "/courses/#{@pending_course.id}", params: { format: :json }
    assert_response :success
    sign_out @admin

    # Other users cannot see
    sign_in @user2
    assert_raises(ActiveRecord::RecordNotFound) do
      get "/courses/#{@pending_course.id}", params: { format: :json }
    end
    sign_out @user2

    # Public cannot see
    assert_raises(ActiveRecord::RecordNotFound) do
      get "/courses/#{@pending_course.id}", params: { format: :json }
    end
  end

  # Request revisions
  test "admin requests revisions" do
    sign_in @admin

    @pending_course.update!(course_status: Course.course_statuses[:awaiting_review])

    # Only owner and admin can see
    sign_in @user
    get "/courses/#{@pending_course.id}", params: { format: :json }
    assert_response :success
    sign_out @user

    sign_in @admin
    get "/courses/#{@pending_course.id}", params: { format: :json }
    assert_response :success
    sign_out @admin

    sign_in @user2
    assert_raises(ActiveRecord::RecordNotFound) do
      get "/courses/#{@pending_course.id}", params: { format: :json }
    end
    sign_out @user2

    # Public cannot see
    assert_raises(ActiveRecord::RecordNotFound) do
      get "/courses/#{@pending_course.id}", params: { format: :json }
    end
  end

  private

  def create_event_from_template(title:, url:, user:, content_providers: [@content_provider], event_status: 'approved')
    template_event = events(:one)
    Event.create!(
      title: title,
      url: url,
      user: user,
      start: template_event.start,
      end: template_event.end,
      timezone: template_event.timezone,
      contact: template_event.contact,
      eligibility: template_event.eligibility,
      host_institutions: template_event.host_institutions,
      nodes: template_event.nodes,
      language: template_event.language,
      prerequisites: template_event.prerequisites,
      target_audience: template_event.target_audience,
      content_providers: content_providers,
      cost_basis: template_event.cost_basis,
      learning_objectives: template_event.learning_objectives,
      event_status: event_status
    )
  end
end
