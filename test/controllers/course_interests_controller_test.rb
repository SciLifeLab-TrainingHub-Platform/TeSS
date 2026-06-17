require "test_helper"

class CourseInterestsControllerTest  < ActionController::TestCase
  include Devise::Test::ControllerHelpers

  setup do
    @user = users(:regular_user)
    sign_in @user

    @course = courses(:one)
  end

  # test for non logged in users
  test "should redirect with alert when user is not logged in" do
    sign_out @user
    post :create, params: { course_id: @course.to_param }
    assert_redirected_to new_user_session_path
  end

  # Successful subscribe
  test "should subscribe user and redirect with notice" do
    service_stub = lambda do |course:, user:|
      assert_equal @course, course
      assert_equal @user, user
      {
        status: :success,
        message: "You have subscribed successfully"
      }
    end
    CourseInterestService.stub(:subscribe_user!, service_stub) do
      post :create, params: { course_id: @course.to_param }
    end
    assert_redirected_to course_path(@course)
    assert_equal "You have subscribed successfully", flash[:notice]
  end

  # unsuccessful subscribe
  test "should redirect with alert when subscription fails" do
    service_stub = lambda do |course:, user:|
      assert_equal @course, course
      assert_equal @user, user
      {
        status: :error,
        message: "Already subscribed."
      }
    end

    CourseInterestService.stub(:subscribe_user!, service_stub) do
      post :create, params: { course_id: @course.to_param }
    end

    assert_redirected_to course_path(@course)
    assert_equal "Already subscribed.", flash[:alert]
  end


  # course not found
  test "should redirect to courses path when course is not found" do
    post :create, params: { course_id: "invalid-course" }

    assert_redirected_to courses_path
    assert_equal "Course not found", flash[:alert]
  end

  # generic error
  test "should redirect with generic error when exception occurs" do
    service_stub = lambda do |course:, user:|
      raise StandardError
    end

    CourseInterestService.stub(:subscribe_user!, service_stub) do
      post :create, params: { course_id: @course.to_param }
    end

    assert_redirected_to course_path(@course)
    assert_equal "Something went wrong. Please try again.", flash[:alert]
  end

  # successful unsubscribe
  test "should unsubscribe user and redirect with notice" do
    service_stub = lambda do |course:, user:|
      assert_equal @course, course
      assert_equal @user, user

      {
        status: :success,
        message: "You have unsubscribed successfully"
      }
    end

    CourseInterestService.stub(:unsubscribe_user!, service_stub) do
      delete :destroy, params: { course_id: @course.to_param }
    end

    assert_redirected_to course_path(@course)
    assert_equal "You have unsubscribed successfully", flash[:notice]
  end

  # unsuccessful unsubscribe
  test "should redirect with alert when unsubscription fails" do
    service_stub = lambda do |course:, user:|
      assert_equal @course, course
      assert_equal @user, user

      {
        status: :error,
        message: "You are not currently subscribed"
      }
    end

    CourseInterestService.stub(:unsubscribe_user!, service_stub) do
      delete :destroy, params: { course_id: @course.to_param }
    end

    assert_redirected_to course_path(@course)
    assert_equal "You are not currently subscribed", flash[:alert]
  end

  # test for non logged in users in destroy
  test "should redirect to sign in when user is not logged in" do
    sign_out @user
    delete :destroy, params: { course_id: @course.to_param }
    assert_redirected_to new_user_session_path
  end

  # Course not found
  test "should redirect to courses path when course is not found in destroy" do
    delete :destroy, params: { course_id: "invalid-course" }

    assert_redirected_to courses_path
    assert_equal "Course not found", flash[:alert]
  end

  # generic error in destroy
  test "should redirect with generic error when exception occurs in destroy" do
    service_stub = lambda do |course:, user:|
      raise StandardError
    end

    CourseInterestService.stub(:unsubscribe_user!, service_stub) do
      delete :destroy, params: { course_id: @course.to_param }
    end

    assert_redirected_to course_path(@course)
    assert_equal "Something went wrong. Please try again.", flash[:alert]
  end
end
