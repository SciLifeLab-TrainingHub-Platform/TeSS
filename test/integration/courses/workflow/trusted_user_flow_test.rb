# test/integration/courses/workflow/trusted_user_flow_test.rb
require 'test_helper'

# Tests for trusted users creating courses.
# Workflow:
# - Trusted user creates a course
# - Course is automatically approved
# - Emails are sent to:
#   - The user (confirmation)
#   - The content provider
# - Slack notification is sent
# - Visibility rules:
#   - All users and public can see the course

class TrustedUserCourseFlowTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper
  include ActiveJob::TestHelper
  include Devise::Test::IntegrationHelpers

  setup do
    @trusted_user = users(:trusted_user)
    @regular_user = users(:regular_user)
    @content_provider = content_providers(:approval_notification_email_contact_provider)
    @course_fixture = courses(:one)
    @node = nodes(:good)

    @parameters = {
      title: 'Trusted user published course',
      url: 'https://example.com/test_course',
      language: 'en',
      licence: 'Glide',
      description: 'A test description',
      target_audience: ['students'],
      prerequisites_knowledge: 'None',
      prerequisites_technical: 'None',
      structure_and_duration: '1 week',
      learning_outcomes: 'Learn testing',
      keywords: %w[test ruby],
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

  test 'trusted user creates approved course and triggers notifications' do
    sign_in @trusted_user

    course = nil

    perform_enqueued_jobs do
      assert_emails 2 do
        course = @trusted_user.courses.create!(@parameters)
      end

      assert course.persisted?
      assert_equal 'Trusted user published course', course.title
      assert_equal 'approved', course.course_status
      assert_equal @trusted_user, course.user
    end

    # Emails
    user_email = ActionMailer::Base.deliveries.find { |m| m.to.include?(@trusted_user.email) }
    provider_email = ActionMailer::Base.deliveries.find { |m| m.to.include?(@content_provider.approval_notification_email) }

    assert_not_nil user_email
    assert_match "Your course '#{course.title}' has been successfully published", user_email.subject

    assert_not_nil provider_email
    assert_match "New course ‘#{course.title}’ submitted for ‘#{@content_provider.title}’", provider_email.subject

    sign_out @trusted_user
  end

  test 'approved course visibility for all users and public' do
    sign_in @trusted_user
    course = @trusted_user.courses.create!(@parameters)
    sign_out @trusted_user

    assert_equal 'approved', course.course_status

    # Public index
    get '/courses', params: { format: :json }
    assert_response :success
    courses_index = JSON.parse(response.body)
    assert_includes courses_index.map { |c| c['id'] }, course.id

    # Public show
    get "/courses/#{course.id}", params: { format: :json }
    assert_response :success
    course_show = JSON.parse(response.body)
    assert_equal course.id, course_show['id']

    # Regular user
    sign_in @regular_user
    get '/courses', params: { format: :json }
    courses_index = JSON.parse(response.body)
    assert_includes courses_index.map { |c| c['id'] }, course.id

    get "/courses/#{course.id}", params: { format: :json }
    assert_response :success

    sign_out @regular_user
  end
end
