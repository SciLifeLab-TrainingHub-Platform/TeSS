require "test_helper"

class CourseInterestsControllerTest < ActionDispatch::IntegrationTest
  test "should get subscribe" do
    get course_interests_subscribe_url
    assert_response :success
  end

  test "should get unsubscribe" do
    get course_interests_unsubscribe_url
    assert_response :success
  end

  test "should get subscribe_as_guest" do
    get course_interests_subscribe_as_guest_url
    assert_response :success
  end

  test "should get request_unsubscribe_email" do
    get course_interests_request_unsubscribe_email_url
    assert_response :success
  end

  test "should get confirm_subscription" do
    get course_interests_confirm_subscription_url
    assert_response :success
  end

  test "should get confirm_unsubscribe" do
    get course_interests_confirm_unsubscribe_url
    assert_response :success
  end
end
