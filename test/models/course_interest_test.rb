require "test_helper"

class CourseInterestTest < ActiveSupport::TestCase

  setup do
    mock_images
  end

  test 'must have user or email' do
  end

  # subscribe!
  test 'subscribe! returns invalid when user is nil' do
  end
  test 'subscribe! creates a new subscription' do
  end
  test 'subscribe! subscribes an existing interest' do
  end
  test 'subscribe! returns already subscribed when user is already subscribed' do
  end

  # unsubscribe!
  test 'unsubscribe! returns invalid when user is nil' do
  end
  test 'unsubscribe! returns not subscribed when interest does not exist' do
  end
  test 'unsubscribe! returns not subscribed when interest is already unsubscribed' do
  end
  test 'unsubscribe! unsubscribes a subscribed user' do
  end

  # request_subscribe!
  test 'request_subscribe! returns invalid when email is blank' do
  end
  test 'request_subscribe! creates a pending subscription request' do
  end
  test 'request_subscribe! normalizes email before saving' do
  end
  test 'request_subscribe! returns already subscribed when email is already subscribed' do
  end
  test 'request_subscribe! updates existing interest to pending subscription' do
  end

  # request_unsubscribe!
  test 'request_unsubscribe! returns invalid when email is blank' do
  end
  test 'request_unsubscribe! returns not subscribed when interest does not exist' do
  end
  test 'request_unsubscribe! returns not subscribed when interest is not subscribed' do
  end
  test 'request_unsubscribe! returns pending when already pending unsubscription' do
  end
  test 'request_unsubscribe! updates subscribed interest to pending unsubscription' do
  end

  # confirm_subscription
  test 'confirm_subscription returns invalid when interest is nil' do
  end
  test 'confirm_subscription returns already subscribed when already subscribed' do
  end
  test 'confirm_subscription subscribes a pending subscription' do
  end

  # confirm_unsubscription
  test 'confirm_unsubscription returns invalid when interest is nil' do
  end
  test 'confirm_unsubscription returns already unsubscribed when already unsubscribed' do
  end
  test 'confirm_unsubscription returns not subscribed when interest is pending subscription' do
  end
  test 'confirm_unsubscription returns not subscribed when interest is not subscribable' do
  end
  test 'confirm_unsubscription unsubscribes a subscribed interest' do
  end
  test 'confirm_unsubscription unsubscribes a pending unsubscription interest' do
  end

  # enum
  test 'status enum defines expected values' do
  end

end
