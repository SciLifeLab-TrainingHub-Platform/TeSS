# frozen_string_literal: true

require 'test_helper'

class CourseInterestServiceTest < ActiveSupport::TestCase
  def setup

  end

  # subscribe_user!
  test 'subscribe_user! returns success when subscribed' do
  end

  test 'subscribe_user! returns already subscribed when already subscribed' do
  end

  test 'subscribe_user! returns error when request is invalid' do
  end

  test 'subscribe_user! returns generic error for unexpected result' do
  end

  # unsubscribe_user!
  test 'unsubscribe_user! returns success when unsubscribed' do
  end

  test 'unsubscribe_user! returns not subscribed when not subscribed' do
  end

  test 'unsubscribe_user! returns error when request is invalid' do
  end

  test 'unsubscribe_user! returns generic error for unexpected result' do
  end

  # request_subscription!
  test 'request_subscription! sends confirmation email when pending' do
  end

  test 'request_subscription! returns already subscribed when already subscribed' do
  end

  test 'request_subscription! returns error when request is invalid' do
  end

  test 'request_subscription! returns generic error for unexpected result' do
  end

  # request_unsubscription!
  test 'request_unsubscription! sends confirmation email when pending' do
  end

  test 'request_unsubscription! returns not subscribed when not subscribed' do
  end

  test 'request_unsubscription! returns error when request is invalid' do
  end

  test 'request_unsubscription! returns generic error for unexpected result' do
  end

  # confirm_subscription!
  test 'confirm_subscription! returns success when subscription confirmed' do
  end

  test 'confirm_subscription! returns already subscribed when already subscribed' do
  end

  test 'confirm_subscription! returns error when request is invalid' do
  end

  test 'confirm_subscription! returns generic error for unexpected result' do
  end

  # confirm_unsubscription
  test 'confirm_unsubscription returns success when unsubscription confirmed' do
  end

  test 'confirm_unsubscription returns already unsubscribed when already unsubscribed' do
  end

  test 'confirm_unsubscription returns not subscribed when subscription not found' do
  end

  test 'confirm_unsubscription returns error when request is invalid' do
  end

  test 'confirm_unsubscription returns generic error for unexpected result' do
  end

  # generate_subscription_token
  test 'generate_subscription_token generates signed token with purpose and expiry' do
  end

end
