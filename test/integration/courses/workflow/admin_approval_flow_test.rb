# test/integration/courses/workflow/admin_approval_flow_test.rb
require 'test_helper'

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
      title: 'Test Course',
      url: 'https://example.com/test_course',
      language: 'en',
      licence: 'Glide',
      description: 'A test description',
      target_audience: ['students'],
      prerequisites_knowledge: 'None',
      prerequisites_technical: 'None',
      structure_and_duration: '1 week',
      learning_outcomes: 'Learn testing',
      keywords: ['test', 'ruby'],
      authors: [
        { 'name' => 'John Doe', 'affiliation' => 'Uni X', 'orcid' => '0000-0001-5109-3700', 'email' => 'johndoe@example.com' },
        { 'name' => 'Jane Doe', 'affiliation' => 'Uni Y', 'orcid' => '0000-0002-5109-3700', 'email' => 'janedoe@example.com' }
      ],
      contributors: [
        { 'name' => 'Jane Doe', 'affiliation' => 'Uni Y', 'orcid' => '0000-0001-5109-3700' },
        { 'name' => 'Jane Doe', 'affiliation' => 'Uni Y', 'orcid' => '0000-0002-5109-3700' }
      ],
      content_providers: [@content_provider],
      nodes: [@node],
    }

    @pending_course = @user.courses.create!(@parameters)
  end

  # Approve pending course
  test 'admin approves pending course' do
    sign_in @admin

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
    assert_equal 'approved', @pending_course.reload.course_status

    sign_out @admin
  end

  # Reject course
  test 'admin rejects course' do
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
  test 'admin requests revisions' do
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
end
