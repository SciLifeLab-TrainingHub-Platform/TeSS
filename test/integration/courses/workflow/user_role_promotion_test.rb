# test/integration/courses/workflow/user_role_promotion_test.rb
require "test_helper"

# Tests for automatic user promotion to trusted role based on approved courses.
# Covers:
# - User reaches COURSE_APPROVAL_THRESHOLD for approved courses
# - User is automatically promoted to the trusted role
# - Future courses created by the promoted user are auto-approved
# - Verification that users below the threshold are not prematurely promoted
# - Ensures database reflects the correct role for the user
# - Ensures workflow behavior changes after promotion (trusted user flow applies)

class UserRolePromotionCourseTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include ActionMailer::TestHelper
  include ActiveJob::TestHelper

  setup do
    @user = users(:regular_user)
    @user2 = users(:another_regular_user2)
    @admin = users(:admin)
    @content_provider = content_providers(:approval_notification_email_contact_provider)
    @trusted_user_role = roles(:trusted_user)
    @registered_user_role = roles(:user)
    @node = nodes(:good)

    @course_params = {
      title: "course title",
      url: "https://example.com/test_course",
      language: "en",
      licence: "Glide",
      description: "A test description",
      target_audience: ["students"],
      prerequisites_knowledge: "None",
      prerequisites_technical: "None",
      structure_and_duration: "1 week",
      learning_outcomes: "Learn testing",
      keywords: %w[test ruby],
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

    @threshold = User::EVENT_APPROVAL_THRESHOLD
  end

  test "user is promoted to trusted after reaching course approval threshold" do
    sign_in @admin

    assert_equal @registered_user_role.name, @user.role.name, "User should be registered user"
    perform_enqueued_jobs do
      (@threshold + 1).times do |i|
        course = @user.courses.create!(@course_params.merge(title: "Approved Course #{i + 1}"))
        course.update!(course_status: Course.course_statuses[:approved])
      end
    end

    @user.reload
    assert_equal @trusted_user_role.name, @user.role.name, "User should be promoted to trusted after threshold approvals"
  end

  test "future courses by promoted user are automatically approved" do
    sign_in @admin
    assert_equal @registered_user_role.name, @user.role.name, "User should be registered user"
    (@threshold + 1).times do |i|
      course = @user.courses.create!(@course_params.merge(title: "Approved Course #{i + 1}"))
      course.update!(course_status: Course.course_statuses[:approved])
    end

    @user.reload
    assert_equal @trusted_user_role.name, @user.role.name

    sign_in @user
    perform_enqueued_jobs do
      new_course = @user.courses.create!(@course_params.merge(title: "Future Course Auto-Approved"))
      assert_equal Course.course_statuses.key(Course.course_statuses[:approved]), new_course.course_status
    end
  end

  test "user below threshold is not promoted" do
    sign_in @admin
    (@threshold - 1).times do |i|
      course = @user2.courses.create!(@course_params.merge(title: "Approved Course #{i + 1}"))
      course.update!(course_status: "approved")
    end
    @user2.reload
    assert_equal @registered_user_role.name, @user2.role.name, "User should not be promoted before reaching threshold"
  end

  test "database reflects correct roles after promotion and non-promotion" do
    sign_in @admin
    (@threshold + 1).times do |i|
      course = @user.courses.create!(@course_params.merge(title: "Approved Course #{i + 1}"))
      course.update!(course_status: "approved")
    end

    # @user2 still below threshold
    (@threshold - 1).times do |i|
      course = @user2.courses.create!(@course_params.merge(title: "Approved Course #{i + 1}"))
      course.update!(course_status: "approved")
    end

    @user.reload
    @user2.reload

    assert_equal @trusted_user_role.name, @user.role.name
    assert_equal @registered_user_role.name, @user2.role.name
  end
end
