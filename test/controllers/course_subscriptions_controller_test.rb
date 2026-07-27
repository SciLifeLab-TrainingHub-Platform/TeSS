require "test_helper"

class CourseSubscriptionsControllerTest < ActionController::TestCase
  include Devise::Test::ControllerHelpers

  setup do
    @user = users(:regular_user)
    @course = courses(:one)
    @interest = course_interests(:one)
  end

  # tests for request_email_action method
  test "request_email_action should redirect logged in user to root path" do
    sign_in @user

    post :request_email_action,
         params: {
           course_id: @course.to_param,
           email: "test@example.com",
           action_type: CourseInterest::ACTION_REQUEST_SUBSCRIBE
         }

    assert_redirected_to root_path
    assert_equal(
      "Logged-in users should manage subscriptions through their account.",
      flash[:alert]
    )
  end

  test "request_email_action should request subscription and redirect with notice" do
    sign_out @user

    service_stub = lambda do |course:, email:, ip: nil|
      assert_equal @course, course
      assert_equal "test@example.com", email

      {
        status: :ok,
        message: "Subscription confirmation email sent"
      }
    end

    CourseInterestService.stub(:request_subscription!, service_stub) do
      post :request_email_action,
           params: {
             course_id: @course.to_param,
             email: "test@example.com",
             action_type: CourseInterest::ACTION_REQUEST_SUBSCRIBE
           }
    end

    assert_redirected_to course_path(@course)
    assert_equal "Subscription confirmation email sent", flash[:notice]
  end

  test "request_email_action should redirect with alert when subscription request fails" do
    sign_out @user

    CourseInterestService.stub(
      :request_subscription!,
      {
        status: :error,
        message: "Invalid request"
      }
    ) do
      post :request_email_action,
           params: {
             course_id: @course.to_param,
             email: "test@example.com",
             action_type: CourseInterest::ACTION_REQUEST_SUBSCRIBE
           }
    end

    assert_redirected_to course_path(@course)
    assert_equal "Invalid request", flash[:alert]
  end

  test "request_email_action should request unsubscription and redirect with notice" do
    sign_out @user

    service_stub = lambda do |course:, email:, ip: nil|
      assert_equal @course, course
      assert_equal "test@example.com", email

      {
        status: :ok,
        message: "Unsubscription confirmation email sent"
      }
    end

    CourseInterestService.stub(:request_unsubscription!, service_stub) do
      post :request_email_action,
           params: {
             course_id: @course.to_param,
             email: "test@example.com",
             action_type: CourseInterest::ACTION_REQUEST_UNSUBSCRIBE
           }
    end

    assert_redirected_to course_path(@course)
    assert_equal "Unsubscription confirmation email sent", flash[:notice]
  end

  test "request_email_action should redirect with alert for invalid action type" do
    sign_out @user

    post :request_email_action,
         params: {
           course_id: @course.to_param,
           email: "test@example.com",
           action_type: "invalid_action"
         }

    assert_redirected_to course_path(@course)
    assert_equal "Invalid action", flash[:alert]
  end

  test "request_email_action should redirect to courses path when course is not found" do
    post :request_email_action,
         params: {
           course_id: "invalid-course",
           email: "test@example.com",
           action_type: CourseInterest::ACTION_REQUEST_SUBSCRIBE
         }

    assert_redirected_to courses_path
    assert_equal "Course not found", flash[:alert]
  end

  test "request_email_action should redirect with generic error when exception occurs" do
    sign_out @user

    service_stub = lambda do |course:, email:, ip: nil|
      raise StandardError
    end

    CourseInterestService.stub(:request_subscription!, service_stub) do
      post :request_email_action,
           params: {
             course_id: @course.to_param,
             email: "test@example.com",
             action_type: CourseInterest::ACTION_REQUEST_SUBSCRIBE
           }
    end

    assert_redirected_to course_path(@course)
    assert_equal "Something went wrong. Please try again.", flash[:alert]
  end

  # tests for confirm_course_subscription method
  test "confirm_course_subscription redirects with notice when subscription is confirmed" do

    interest = course_interests(:one)
    service_stub = lambda do |interest:|
      assert_equal course_interests(:one), interest
      {
        status: :ok,
        message: "Subscription confirmed successfully"
      }
    end
    CourseInterest.stub(:find_signed!, interest) do
      CourseInterestService.stub(:confirm_subscription!, service_stub) do
        get :confirm_course_subscription,
            params: {
              course_id: @course.to_param,
              token: "valid-token"
            }
      end
    end
    assert_redirected_to course_path(@course)
    assert_equal "Subscription confirmed successfully", flash[:notice]
  end

  test "confirm_course_subscription redirects with alert when service returns error" do
    interest = course_interests(:one)

    service_stub = lambda do |interest:|
      assert_equal course_interests(:one), interest

      {
        status: :error,
        message: "Invalid subscription link"
      }
    end

    CourseInterest.stub(:find_signed!, interest) do
      CourseInterestService.stub(:confirm_subscription!, service_stub) do
        get :confirm_course_subscription,
            params: {
              course_id: @course.to_param,
              token: "valid-token"
            }
      end
    end

    assert_redirected_to course_path(@course)
    assert_equal "Invalid subscription link", flash[:alert]
  end

  test "confirm_course_subscription redirects with alert when token course does not match" do
    interest = course_interests(:one)

    interest.stub(:course_id, courses(:two).id) do
      CourseInterest.stub(:find_signed!, interest) do
        get :confirm_course_subscription,
            params: {
              course_id: @course.to_param,
              token: "valid-token"
            }
      end
    end

    assert_redirected_to course_path(@course)
    assert_equal "Invalid confirmation link", flash[:alert]
  end

  test "confirm_course_subscription redirects with alert when token is invalid" do
    CourseInterest.stub(
      :find_signed!,
      ->(*) { raise ActiveSupport::MessageVerifier::InvalidSignature }
    ) do
      get :confirm_course_subscription,
          params: {
            course_id: @course.to_param,
            token: "invalid-token"
          }
    end

    assert_redirected_to course_path(@course)
    assert_equal "Invalid or expired confirmation link", flash[:alert]
  end

  test "confirm_course_subscription redirects to courses path when course is not found" do
    get :confirm_course_subscription,
        params: {
          course_id: "invalid-course",
          token: "valid-token"
        }

    assert_redirected_to courses_path
    assert_equal "Course not found", flash[:alert]
  end

  test "confirm_course_subscription redirects with alert when unexpected error occurs" do
    interest = course_interests(:one)

    CourseInterest.stub(:find_signed!, interest) do
      CourseInterestService.stub(
        :confirm_subscription!,
        ->(*) { raise StandardError }
      ) do
        get :confirm_course_subscription,
            params: {
              course_id: @course.to_param,
              token: "valid-token"
            }
      end
    end

    assert_redirected_to course_path(@course)
    assert_equal "Something went wrong. Please try again.", flash[:alert]
  end

  # tests for confirm_course_unsubscription method
  test "confirm_course_unsubscription redirects with notice when unsubscription is confirmed" do
    interest = course_interests(:one)

    service_stub = lambda do |interest|
      assert_equal course_interests(:one), interest
      {
        status: :ok,
        message: "You have been unsubscribed successfully"
      }
    end

    CourseInterest.stub(:find_signed!, interest) do
      CourseInterestService.stub(:confirm_unsubscription, service_stub) do
        get :confirm_course_unsubscription,
            params: {
              course_id: @course.to_param,
              token: "valid-token"
            }
      end
    end

    assert_redirected_to course_path(@course)
    assert_equal "You have been unsubscribed successfully", flash[:notice]
  end

  test "confirm_course_unsubscription redirects with alert when service returns error" do
    interest = course_interests(:one)

    service_stub = lambda do |interest|
      {
        status: :error,
        message: "Invalid unsubscription link"
      }
    end

    CourseInterest.stub(:find_signed!, interest) do
      CourseInterestService.stub(:confirm_unsubscription, service_stub) do
        get :confirm_course_unsubscription,
            params: {
              course_id: @course.to_param,
              token: "valid-token"
            }
      end
    end

    assert_redirected_to course_path(@course)
    assert_equal "Invalid unsubscription link", flash[:alert]
  end

  test "confirm_course_unsubscription redirects with alert when token course does not match" do
    interest = Struct.new(:course_id).new(-1)

    CourseInterest.stub(:find_signed!, interest) do
      get :confirm_course_unsubscription,
          params: {
            course_id: @course.to_param,
            token: "valid-token"
          }
    end

    assert_redirected_to course_path(@course)
    assert_equal "Invalid confirmation link", flash[:alert]
  end

  test "confirm_course_unsubscription redirects with alert when token is invalid" do
    CourseInterest.stub(
      :find_signed!,
      ->(*) { raise ActiveSupport::MessageVerifier::InvalidSignature }
    ) do
      get :confirm_course_unsubscription,
          params: {
            course_id: @course.to_param,
            token: "invalid-token"
          }
    end

    assert_redirected_to course_path(@course)
    assert_equal "Invalid or expired confirmation link", flash[:alert]
  end

  test "confirm_course_unsubscription redirects to courses path when course is not found" do
    get :confirm_course_unsubscription,
        params: {
          course_id: "invalid-course",
          token: "valid-token"
        }

    assert_redirected_to courses_path
    assert_equal "Course not found", flash[:alert]
  end

  test "confirm_course_unsubscription redirects with alert when unexpected error occurs" do
    interest = course_interests(:one)

    CourseInterest.stub(:find_signed!, interest) do
      CourseInterestService.stub(
        :confirm_unsubscription,
        ->(*) { raise StandardError }
      ) do
        get :confirm_course_unsubscription,
            params: {
              course_id: @course.to_param,
              token: "valid-token"
            }
      end
    end

    assert_redirected_to course_path(@course)
    assert_equal "Something went wrong. Please try again.", flash[:alert]
  end
end
