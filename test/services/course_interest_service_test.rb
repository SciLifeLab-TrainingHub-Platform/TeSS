# frozen_string_literal: true

require 'test_helper'

class CourseInterestServiceTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include ActiveSupport::Testing::TimeHelpers

  def setup
    @course = courses(:one)
    @user = users(:regular_user)
  end

  # subscribe_user!
  test 'subscribe_user! returns success response when subscription is created' do
    CourseInterest.stub(
      :subscribe!,
      CourseInterest::RESULT_SUBSCRIBED
    ) do
      result = CourseInterestService.subscribe_user!(
        course: @course,
        user: @user
      )
      assert_equal :ok, result[:status]
      assert_equal 'You have subscribed successfully', result[:message]
      assert_equal CourseInterest::RESULT_SUBSCRIBED, result[:result]
    end
  end

  test 'subscribe_user! returns already subscribed response when user is already subscribed' do
    CourseInterest.stub(
      :subscribe!,
      CourseInterest::RESULT_ALREADY_SUBSCRIBED
    ) do
      result = CourseInterestService.subscribe_user!(
        course: @course,
        user: @user
      )

      assert_equal :ok, result[:status]
      assert_equal 'You are already subscribed', result[:message]
      assert_equal CourseInterest::RESULT_ALREADY_SUBSCRIBED, result[:result]
    end
  end

  test 'subscribe_user! returns invalid request response when subscription is invalid' do
    CourseInterest.stub(
      :subscribe!,
      CourseInterest::RESULT_INVALID
    ) do
      result = CourseInterestService.subscribe_user!(
        course: @course,
        user: @user
      )

      assert_equal :error, result[:status]
      assert_equal 'Invalid request', result[:message]
      assert_equal CourseInterest::RESULT_INVALID, result[:result]
    end
  end

  test 'subscribe_user! returns generic error response for unexpected result' do
    CourseInterest.stub(:subscribe!, :some_unknown_value) do
      result = CourseInterestService.subscribe_user!(
        course: @course,
        user: @user
      )
      assert_equal :error, result[:status]
      assert_equal 'Something went wrong', result[:message]
      assert_equal :some_unknown_value, result[:result]
    end
  end

  # unsubscribe_user!
  test 'unsubscribe_user! returns success response when user is unsubscribed' do
    CourseInterest.stub(:unsubscribe!, CourseInterest::RESULT_UNSUBSCRIBED) do
      result = CourseInterestService.unsubscribe_user!(
        course: @course,
        user: @user
      )

      assert_equal :ok, result[:status]
      assert_equal 'You have unsubscribed successfully', result[:message]
      assert_equal CourseInterest::RESULT_UNSUBSCRIBED, result[:result]
    end
  end

  test 'unsubscribe_user! returns already not subscribed response when user is not subscribed' do
    CourseInterest.stub(:unsubscribe!, CourseInterest::RESULT_NOT_SUBSCRIBED) do
      result = CourseInterestService.unsubscribe_user!(
        course: @course,
        user: @user
      )

      assert_equal :ok, result[:status]
      assert_equal 'You are not currently subscribed', result[:message]
      assert_equal CourseInterest::RESULT_NOT_SUBSCRIBED, result[:result]
    end
  end

  test 'unsubscribe_user! returns error response when request is invalid' do
    CourseInterest.stub(:unsubscribe!, CourseInterest::RESULT_INVALID) do
      result = CourseInterestService.unsubscribe_user!(
        course: @course,
        user: @user
      )

      assert_equal :error, result[:status]
      assert_equal 'Invalid request', result[:message]
      assert_equal CourseInterest::RESULT_INVALID, result[:result]
    end
  end

  test 'unsubscribe_user! returns generic error response for unexpected result' do
    CourseInterest.stub(:unsubscribe!, :unexpected_value) do
      result = CourseInterestService.unsubscribe_user!(
        course: @course,
        user: @user
      )

      assert_equal :error, result[:status]
      assert_equal 'Something went wrong', result[:message]
      assert_equal :unexpected_value, result[:result]
    end
  end

  # request_subscription!
  test 'request_subscription! sends confirmation email and returns success when pending' do
    interest = CourseInterest.new

    CourseInterest.stub(
      :request_subscribe!,
      [CourseInterest::RESULT_PENDING, interest]
    ) do

      assert_enqueued_jobs 1 do
        result = CourseInterestService.request_subscription!(
          course: @course,
          email: @user.email
        )

        assert_equal :ok, result[:status]
        assert_equal 'Subscription confirmation email sent', result[:message]
        assert_equal CourseInterest::RESULT_PENDING, result[:result]
      end
    end


    perform_enqueued_jobs
    mail = ActionMailer::Base.deliveries.last

    assert_not_nil mail
    assert_equal [@user.email], mail.to
    assert_match @course.title, mail.body.encoded
  end

  test 'request_subscription! returns already subscribed response when user already subscribed' do
    CourseInterest.stub(
      :request_subscribe!,
      [CourseInterest::RESULT_ALREADY_SUBSCRIBED, nil]
    ) do
      result = CourseInterestService.request_subscription!(
        course: @course,
        email: @user.email
      )

      assert_equal :ok, result[:status]
      assert_equal 'You are already subscribed', result[:message]
      assert_equal CourseInterest::RESULT_ALREADY_SUBSCRIBED, result[:result]
    end
  end

  test 'request_subscription! returns invalid request response when request is invalid' do
    CourseInterest.stub(
      :request_subscribe!,
      [CourseInterest::RESULT_INVALID, nil]
    ) do
      result = CourseInterestService.request_subscription!(
        course: @course,
        email: @user.email
      )

      assert_equal :error, result[:status]
      assert_equal 'Invalid request', result[:message]
      assert_equal CourseInterest::RESULT_INVALID, result[:result]
    end
  end

  test 'request_subscription! returns generic error response for unexpected result' do
    CourseInterest.stub(
      :request_subscribe!,
      [:unexpected_value, nil]
    ) do
      result = CourseInterestService.request_subscription!(
        course: @course,
        email: @user.email
      )

      assert_equal :error, result[:status]
      assert_equal 'Something went wrong', result[:message]
      assert_equal :unexpected_value, result[:result]
    end
  end

  # request_unsubscription!
  test 'request_unsubscription! sends confirmation email when pending' do
    interest = CourseInterest.new
    CourseInterest.stub(
      :request_unsubscribe!,
      [CourseInterest::RESULT_PENDING, interest]
    ) do

      assert_enqueued_jobs 1 do
        result = CourseInterestService.request_unsubscription!(
          course: @course,
          email: @user.email
        )

        assert_equal :ok, result[:status]
        assert_equal 'Unsubscription confirmation email sent', result[:message]
        assert_equal CourseInterest::RESULT_PENDING, result[:result]
      end
    end

    perform_enqueued_jobs

    mail = ActionMailer::Base.deliveries.last

    assert_not_nil mail
    assert_equal [@user.email], mail.to
    assert_match @course.title, mail.body.encoded
  end

  test 'request_unsubscription! returns not subscribed when user is not subscribed' do
    CourseInterest.stub(
      :request_unsubscribe!,
      [CourseInterest::RESULT_NOT_SUBSCRIBED, nil]
    ) do
      result = CourseInterestService.request_unsubscription!(
        course: @course,
        email: @user.email
      )

      assert_equal :ok, result[:status]
      assert_equal 'You are not currently subscribed', result[:message]
      assert_equal CourseInterest::RESULT_NOT_SUBSCRIBED, result[:result]
    end
  end

  test 'request_unsubscription! returns invalid request response when request is invalid' do
    CourseInterest.stub(
      :request_unsubscribe!,
      [CourseInterest::RESULT_INVALID, nil]
    ) do
      result = CourseInterestService.request_unsubscription!(
        course: @course,
        email: @user.email
      )

      assert_equal :error, result[:status]
      assert_equal 'Invalid request', result[:message]
      assert_equal CourseInterest::RESULT_INVALID, result[:result]
    end
  end

  test 'request_unsubscription! returns generic error response for unexpected result' do
    CourseInterest.stub(
      :request_unsubscribe!,
      [:unexpected_value, nil]
    ) do
      result = CourseInterestService.request_unsubscription!(
        course: @course,
        email: @user.email
      )

      assert_equal :error, result[:status]
      assert_equal 'Something went wrong', result[:message]
      assert_equal :unexpected_value, result[:result]
    end
  end

  # confirm_subscription!
  test 'confirm_subscription! returns success when subscription confirmed' do
    CourseInterest.stub(
      :confirm_subscription,
      CourseInterest::RESULT_SUBSCRIBED
    ) do
      result = CourseInterestService.confirm_subscription!(
        interest: CourseInterest.new
      )

      assert_equal :ok, result[:status]
      assert_equal 'Subscription confirmed successfully', result[:message]
      assert_equal CourseInterest::RESULT_SUBSCRIBED, result[:result]
    end
  end

  test 'confirm_subscription! returns already subscribed when already subscribed' do
    CourseInterest.stub(
      :confirm_subscription,
      CourseInterest::RESULT_ALREADY_SUBSCRIBED
    ) do
      result = CourseInterestService.confirm_subscription!(
        interest: CourseInterest.new
      )

      assert_equal :ok, result[:status]
      assert_equal 'You are already subscribed', result[:message]
      assert_equal CourseInterest::RESULT_ALREADY_SUBSCRIBED, result[:result]
    end
  end

  test 'confirm_subscription! returns error when request is invalid' do
    CourseInterest.stub(
      :confirm_subscription,
      CourseInterest::RESULT_INVALID
    ) do
      result = CourseInterestService.confirm_subscription!(
        interest: CourseInterest.new
      )

      assert_equal :error, result[:status]
      assert_equal 'Invalid subscription link', result[:message]
      assert_equal CourseInterest::RESULT_INVALID, result[:result]
    end
  end

  test 'confirm_subscription! returns generic error for unexpected result' do
    CourseInterest.stub(
      :confirm_subscription,
      :unexpected_value
    ) do
      result = CourseInterestService.confirm_subscription!(
        interest: CourseInterest.new
      )

      assert_equal :error, result[:status]
      assert_equal 'Something went wrong', result[:message]
      assert_equal :unexpected_value, result[:result]
    end
  end

  # confirm_unsubscription
  test 'confirm_unsubscription returns success when unsubscription confirmed' do
    CourseInterest.stub(
      :confirm_unsubscription,
      CourseInterest::RESULT_UNSUBSCRIBED
    ) do
      result = CourseInterestService.confirm_unsubscription(
        CourseInterest.new
      )

      assert_equal :ok, result[:status]
      assert_equal 'You have been unsubscribed successfully', result[:message]
      assert_equal CourseInterest::RESULT_UNSUBSCRIBED, result[:result]
    end
  end

  test 'confirm_unsubscription returns already unsubscribed when already unsubscribed' do
    CourseInterest.stub(
      :confirm_unsubscription,
      CourseInterest::RESULT_ALREADY_UNSUBSCRIBED
    ) do
      result = CourseInterestService.confirm_unsubscription(
        CourseInterest.new
      )

      assert_equal :ok, result[:status]
      assert_equal 'This course is already unsubscribed for the email provided.', result[:message]
      assert_equal CourseInterest::RESULT_ALREADY_UNSUBSCRIBED, result[:result]
    end
  end

  test 'confirm_unsubscription returns not subscribed when subscription not found' do
    CourseInterest.stub(
      :confirm_unsubscription,
      CourseInterest::RESULT_NOT_SUBSCRIBED
    ) do
      result = CourseInterestService.confirm_unsubscription(
        CourseInterest.new
      )

      assert_equal :ok, result[:status]
      assert_equal 'Course subscription not found', result[:message]
      assert_equal CourseInterest::RESULT_NOT_SUBSCRIBED, result[:result]
    end
  end

  test 'confirm_unsubscription returns error when request is invalid' do
    CourseInterest.stub(
      :confirm_unsubscription,
      CourseInterest::RESULT_INVALID
    ) do
      result = CourseInterestService.confirm_unsubscription(
        CourseInterest.new
      )

      assert_equal :error, result[:status]
      assert_equal 'Invalid unsubscription link', result[:message]
      assert_equal CourseInterest::RESULT_INVALID, result[:result]
    end
  end

  test 'confirm_unsubscription returns generic error for unexpected result' do
    CourseInterest.stub(
      :confirm_unsubscription,
      :unexpected_value
    ) do
      result = CourseInterestService.confirm_unsubscription(
        CourseInterest.new
      )

      assert_equal :error, result[:status]
      assert_equal 'Something went wrong', result[:message]
      assert_equal :unexpected_value, result[:result]
    end
  end

  # generate_subscription_token
  test 'generate_subscription_token returns a signed token for the interest' do
    interest = CourseInterest.create!(email: 'test@example.com', course: courses(:one))

    token = CourseInterestService.generate_subscription_token(
      interest,
      :subscription
    )

    assert_not_nil token
    assert_kind_of String, token
  end

  test 'generate_subscription_token produces different tokens for different purposes' do
    interest = CourseInterest.create!(email: 'test@example.com', course: courses(:one))

    token1 = CourseInterestService.generate_subscription_token(
      interest,
      "purpose 1"
    )

    token2 = CourseInterestService.generate_subscription_token(
      interest,
      "purpose 2"
    )

    assert_not_equal token1, token2
  end

  test 'token becomes invalid after expiry time' do
    purpose = "some purpose"

    interest = CourseInterest.create!(
      email: 'test@example.com',
      course: courses(:one)
    )

    token = CourseInterestService.generate_subscription_token(
      interest,
      purpose
    )

    # token should be valid immediately
    assert CourseInterest.find_signed(token, purpose: purpose)

    # simulate 8 days later (past CourseInterestService::COURSE_INTEREST_TOKEN_EXPIRY day expiry)
    travel 8.days do
      assert_nil CourseInterest.find_signed(token, purpose: purpose)
    end
  end

end
