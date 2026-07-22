# test/integration/courses/workflow/registered_user_flow_test.rb
require 'test_helper'

# Tests for registered (non-trusted) users creating courses.
# This includes the full workflow for a registered user:
# - Creating a new course below any approval threshold
# - Course is set to pending approval
# - Emails are sent to the admin notifying them of the pending course
# - Emails are sent to the user confirming their course is pending
# - Visibility rules for pending courses:
#   - Only the course owner and admin can see the course
#   - Other users and the public cannot view the course in index or show pages
# - Updating a course in "revisions_required" state by the owner:
#   - Status is reset to awaiting_review
#   - Admin is notified that the course was updated

class RegisteredUserCourseFlowTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper
  include ActiveJob::TestHelper
  include Devise::Test::IntegrationHelpers

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
  end

  test 'registered user creates pending course and triggers emails' do
    sign_in @user

    perform_enqueued_jobs do
      get '/courses/new'
      assert_response :success

      course = nil

      # Ensure emails sent to admin + user
      assert_emails 2 do
        course = @user.courses.create!(@parameters)

        assert course.persisted?
        assert_equal 'Test Course', course.title
        assert_equal 'awaiting_review', course.course_status
        assert_equal @user, course.user
      end

      admin_email = ActionMailer::Base.deliveries.find { |m| m.to.include?(AdminMailer::ADMIN_EMAIL_ADDRESS) }
      user_email = ActionMailer::Base.deliveries.find { |m| m.to.include?(@user.email) }

      assert_not_nil admin_email
      assert_match "Course review for #{course.title}", admin_email.subject

      assert_not_nil user_email
      assert_match "Your course '#{course.title}' has been successfully submitted", user_email.subject
    end
  end

  test 'pending course visibility' do
    sign_in @user
    get '/courses/new'
    assert_response :success

    course = @user.courses.create!(@parameters)

    assert course.persisted?
    assert_equal 'Test Course', course.title
    assert_equal 'awaiting_review', course.course_status
    assert_equal @user, course.user

    # Index page
    get '/courses', params: { format: :json }
    assert_response :success
    courses_index = JSON.parse(response.body)
    assert_includes courses_index.map { |c| c['id'] }, course.id

    # Show page
    get "/courses/#{course.id}", params: { format: :json }
    assert_response :success
    course_show = JSON.parse(response.body)
    assert_equal course.id, course_show['id']

    sign_out @user

    # Other user cannot see
    sign_in @user2
    get '/courses', params: { format: :json }
    assert_response :success
    courses_index = JSON.parse(response.body)
    if TeSS::Config.solr_enabled
      refute_includes courses_index.map { |c| c['id'] }, course.id
    end

    assert_raises(ActiveRecord::RecordNotFound) do
      get "/courses/#{course.id}", params: { format: :json }
    end

    sign_out @user2

    # Admin can see
    sign_in @admin
    get '/courses', params: { format: :json }
    assert_response :success
    courses_index = JSON.parse(response.body)
    assert_includes courses_index.map { |c| c['id'] }, course.id

    get "/courses/#{course.id}", params: { format: :json }
    assert_response :success
    course_show = JSON.parse(response.body)
    assert_equal course.id, course_show['id']

    sign_out @admin
  end

  test 'owner updating revisions_required course resets status and notifies admin' do
    sign_in @user
    course = @user.courses.create!(@parameters)
    assert_equal 'awaiting_review', course.course_status
    sign_out @user

    sign_in @admin
    course.update_column(:course_status, Course.course_statuses[:revisions_required])
    course.reload
    assert_equal 'revisions_required', course.course_status
    sign_out @admin

    sign_in @user
    perform_enqueued_jobs do
      assert_emails 1 do
        patch course_path(course), params: { course: { title: 'Updated after revisions' } }
      end
    end

    course.reload
    assert_equal 'awaiting_review', course.course_status, 'Course status should reset after owner update'

    admin_email = ActionMailer::Base.deliveries.find do |mail|
      mail.to.include?(AdminMailer::ADMIN_EMAIL_ADDRESS)
    end
    assert_not_nil admin_email, 'Expected admin notification email'

    expected_subject = "Course #{course.title} updated by #{course.user.username}"
    assert_equal expected_subject, admin_email.subject
    assert_match "The course titled #{course.title} has been updated by #{course.user.username}", admin_email.body.encoded
    assert_match 'The course status has been changed to Awaiting review', admin_email.body.encoded
  end
end
