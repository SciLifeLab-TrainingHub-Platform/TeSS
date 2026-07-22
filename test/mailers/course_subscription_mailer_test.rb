# frozen_string_literal: true
require 'test_helper'

class CourseSubscriptionMailerTest < ActionMailer::TestCase

  setup do
    @course = courses(:one)
    @email = "test@example.com"
    @token = "subscription-token"
  end

  test "subscription_confirmation" do

    mail = CourseSubscriptionMailer.subscription_confirmation(
      @email,
      @course,
      @token
    )

    assert_equal [@email], mail.to
    assert_equal(
      "Confirm your subscription for #{@course.title}",
      mail.subject
    )

    assert_emails 1 do
      mail.deliver_now
    end

    assert_match @course.title, mail.body.encoded
    assert_match "You requested to subscribe to updates for the following course:", mail.body.encoded
    assert_match "Confirm your subscription", mail.body.encoded

    assert_match(
      "confirm_course_subscription?token=#{@token}",
      mail.body.encoded
    )

    assert_match(
      "#{(CourseInterestService::COURSE_INTEREST_TOKEN_EXPIRY / 1.day).to_i} days",
      mail.body.encoded
    )
  end

  test "unsubscription_confirmation" do
    mail = CourseSubscriptionMailer.unsubscription_confirmation(
      @email,
      @course,
      @token
    )

    assert_equal [@email], mail.to
    assert_equal(
      "Confirm your unsubscription for #{@course.title}",
      mail.subject
    )

    assert_emails 1 do
      mail.deliver_now
    end

    assert_match @course.title, mail.body.encoded
    assert_match(
      "confirm_course_unsubscription?token=#{@token}",
      mail.body.encoded
    )

    assert_match(
      "#{(CourseInterestService::COURSE_INTEREST_TOKEN_EXPIRY / 1.day).to_i} days",
      mail.body.encoded
    )
  end

end