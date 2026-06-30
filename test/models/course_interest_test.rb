require "test_helper"

class CourseInterestTest < ActiveSupport::TestCase

  setup do
    @course = courses(:one)
    @user = users(:regular_user)
    @user1 = users(:another_regular_user)
    @user2 = users(:another_regular_user2)
  end

  # testing for course interest call back - validate :must_have_user_or_email
  test 'must have user or email' do
    interest = @course.course_interests.build
    assert_not interest.valid?
    assert_includes interest.errors[:base], 'User or email must be present'
  end

  test 'is valid with user' do
    interest = @course.course_interests.create!(
      user: @user
    )
    assert interest.persisted?
  end

  test 'is valid with email' do
    interest = @course.course_interests.create!(
      email: 'test@example.com'
    )
    assert interest.persisted?
  end

  # subscribe!
  test 'subscribe! returns invalid when user is nil' do
    result = CourseInterest.subscribe!(
      course: @course,
      user: nil
    )
    assert_equal CourseInterest::RESULT_INVALID, result
  end

  test 'subscribe! creates and subscribes a new interest' do
    remove_existing_interest

    assert_difference('CourseInterest.count', 1) do
      result = CourseInterest.subscribe!(
        course: @course,
        user: @user
      )
      assert_equal CourseInterest::RESULT_SUBSCRIBED, result
    end
    interest = CourseInterest.find_by!(
      course: @course,
      user: @user
    )

    assert_equal 'subscribed', interest.status
    assert_not_nil interest.subscribed_at
    assert_nil interest.unsubscribed_at
  end

  test 'subscribe! subscribes an existing interest' do
    remove_existing_interest

    interest = @course.course_interests.create!(
      user: @user,
      status: :unsubscribed,
      unsubscribed_at: Time.current
    )
    assert_no_difference('CourseInterest.count') do
      result = CourseInterest.subscribe!(
        course: @course,
        user: @user
      )
      assert_equal CourseInterest::RESULT_SUBSCRIBED, result
    end
    interest.reload

    assert_equal 'subscribed', interest.status
    assert_not_nil interest.subscribed_at
    assert_nil interest.unsubscribed_at
  end

  test 'subscribe! returns already subscribed when interest is already subscribed' do
    remove_existing_interest

    @course.course_interests.create!(
      user: @user,
      status: :subscribed,
      subscribed_at: Time.current
    )
    assert_no_difference('CourseInterest.count') do
      result = CourseInterest.subscribe!(
        course: @course,
        user: @user
      )
      assert_equal CourseInterest::RESULT_ALREADY_SUBSCRIBED, result
    end
  end

  test 'subscribe! converts pending unsubscription to subscribed' do
    remove_existing_interest

    interest = @course.course_interests.create!(
      user: @user,
      status: :pending_unsubscription,
      unsubscribed_at: Time.current
    )

    assert_no_difference('CourseInterest.count') do
      result = CourseInterest.subscribe!(
        course: @course,
        user: @user
      )

      assert_equal CourseInterest::RESULT_SUBSCRIBED, result
    end

    interest.reload

    assert_equal 'subscribed', interest.status
    assert_not_nil interest.subscribed_at
    assert_nil interest.unsubscribed_at
  end

  test 'subscribe! converts pending subscription to subscribed' do
    remove_existing_interest

    interest = @course.course_interests.create!(
      user: @user,
      status: :pending_subscription
    )

    assert_no_difference('CourseInterest.count') do
      result = CourseInterest.subscribe!(
        course: @course,
        user: @user
      )

      assert_equal CourseInterest::RESULT_SUBSCRIBED, result
    end

    interest.reload

    assert_equal 'subscribed', interest.status
    assert_not_nil interest.subscribed_at
    assert_nil interest.unsubscribed_at
  end

  # unsubscribe!
  test 'unsubscribe! returns invalid when user is nil' do
    result = CourseInterest.unsubscribe!(
      course: @course,
      user: nil
    )
    assert_equal CourseInterest::RESULT_INVALID, result
  end

  test 'unsubscribe! returns not subscribed when interest does not exist' do
    remove_existing_interest
    result = CourseInterest.unsubscribe!(
      course: @course,
      user: @user
    )
    assert_equal CourseInterest::RESULT_NOT_SUBSCRIBED, result
  end

  test 'unsubscribe! returns not subscribed when interest is already unsubscribed' do
    remove_existing_interest

    @course.course_interests.create!(
      user: @user,
      status: :unsubscribed,
      unsubscribed_at: Time.current
    )
    result = CourseInterest.unsubscribe!(
      course: @course,
      user: @user
    )
    assert_equal CourseInterest::RESULT_NOT_SUBSCRIBED, result
  end

  test 'unsubscribe! unsubscribes a subscribed user' do
    remove_existing_interest
    interest = @course.course_interests.create!(
      user: @user,
      status: :subscribed,
      subscribed_at: Time.current
    )
    assert_no_difference('CourseInterest.count') do
      result = CourseInterest.unsubscribe!(
        course: @course,
        user: @user
      )
      assert_equal CourseInterest::RESULT_UNSUBSCRIBED, result
    end
    interest.reload
    assert_equal 'unsubscribed', interest.status
    assert_nil interest.subscribed_at
    assert_not_nil interest.unsubscribed_at
  end

  test 'unsubscribe! unsubscribes a pending unsubscription interest' do
    remove_existing_interest

    interest = @course.course_interests.create!(
      user: @user,
      status: :pending_unsubscription
    )

    assert_no_difference('CourseInterest.count') do
      result = CourseInterest.unsubscribe!(
        course: @course,
        user: @user
      )

      assert_equal CourseInterest::RESULT_UNSUBSCRIBED, result
    end

    interest.reload

    assert_equal 'unsubscribed', interest.status
    assert_nil interest.subscribed_at
    assert_not_nil interest.unsubscribed_at
  end

  test 'unsubscribe! unsubscribes a pending subscription interest' do
    remove_existing_interest

    interest = @course.course_interests.create!(
      user: @user,
      status: :pending_subscription
    )

    assert_no_difference('CourseInterest.count') do
      result = CourseInterest.unsubscribe!(
        course: @course,
        user: @user
      )

      assert_equal CourseInterest::RESULT_UNSUBSCRIBED, result
    end

    interest.reload

    assert_equal 'unsubscribed', interest.status
    assert_nil interest.subscribed_at
    assert_not_nil interest.unsubscribed_at
  end

  # request_subscribe!
  test 'request_subscribe! returns invalid when email is blank' do
    result, interest = CourseInterest.request_subscribe!(
      course: @course,
      email: nil
    )
    assert_equal CourseInterest::RESULT_INVALID, result
    assert_nil interest
  end

  test 'request_subscribe! creates a pending subscription request' do
    email = 'test@example.com'
    assert_difference('CourseInterest.count', 1) do
      result, interest = CourseInterest.request_subscribe!(
        course: @course,
        email: email
      )
      assert_equal CourseInterest::RESULT_PENDING, result
      assert_equal 'pending_subscription', interest.status
    end
    interest = CourseInterest.find_by!(
      course: @course,
      email: email
    )
    assert_equal 'pending_subscription', interest.status
  end

  test 'request_subscribe! normalizes email before saving' do
    result, interest = CourseInterest.request_subscribe!(
      course: @course,
      email: '  TEST@Example.COM  '
    )
    assert_equal CourseInterest::RESULT_PENDING, result
    interest.reload
    assert_equal 'test@example.com', interest.email
    assert_equal 'pending_subscription', interest.status
  end



  test 'request_subscribe! returns already subscribed when email is already subscribed' do

    interest = @course.course_interests.create!(
      email: 'test@example.com',
      status: :subscribed,
      subscribed_at: Time.current
    )
    assert_no_difference('CourseInterest.count') do
      result, returned_interest = CourseInterest.request_subscribe!(
        course: @course,
        email: 'test@example.com'
      )
      assert_equal CourseInterest::RESULT_ALREADY_SUBSCRIBED, result
      assert_equal interest, returned_interest
    end
  end

  test 'request_subscribe! updates existing interest to pending subscription' do
    interest = @course.course_interests.create!(
      email: 'test@example.com',
      status: :unsubscribed,
      unsubscribed_at: Time.current
    )
    assert_no_difference('CourseInterest.count') do
      result, returned_interest = CourseInterest.request_subscribe!(
        course: @course,
        email: 'test@example.com'
      )
      assert_equal CourseInterest::RESULT_PENDING, result
      assert_equal interest, returned_interest
    end
    interest.reload
    assert_equal 'pending_subscription', interest.status
  end

  test 'request_subscribe! keeps pending subscription idempotent for same email' do
    email = 'test4@example.com'
    interest = @course.course_interests.create!(
      email: email,
      status: :pending_subscription
    )

    assert_no_difference('CourseInterest.count') do
      result, returned_interest = CourseInterest.request_subscribe!(
        course: @course,
        email: email
      )

      assert_equal CourseInterest::RESULT_PENDING, result
      assert_equal interest, returned_interest
    end

    interest.reload
    assert_equal 'pending_subscription', interest.status
  end

  test 'request_subscribe! converts pending unsubscription to pending subscription' do
    email = 'test5@example.com'
    interest = @course.course_interests.create!(
      email: email,
      status: :pending_unsubscription
    )

    assert_no_difference('CourseInterest.count') do
      result, returned_interest = CourseInterest.request_subscribe!(
        course: @course,
        email: email
      )

      assert_equal CourseInterest::RESULT_PENDING, result
      assert_equal interest, returned_interest
    end

    interest.reload
    assert_equal 'pending_subscription', interest.status
  end

  # request_unsubscribe!
  test 'request_unsubscribe! returns invalid when email is blank' do
    result, interest = CourseInterest.request_unsubscribe!(
      course: @course,
      email: nil
    )
    assert_equal CourseInterest::RESULT_INVALID, result
    assert_nil interest
  end

  test 'request_unsubscribe! returns not subscribed when interest does not exist' do
    result, interest = CourseInterest.request_unsubscribe!(
      course: @course,
      email: 'missinginterest_email@example.com'
    )
    assert_equal CourseInterest::RESULT_NOT_SUBSCRIBED, result
    assert_nil interest
  end

  test 'request_unsubscribe! returns pending when interest is already pending unsubscription' do
    email = 'test_pending_unsubscription@example.com'
    interest = @course.course_interests.create!(
      email: email,
      status: :pending_unsubscription
    )
    result, returned_interest = CourseInterest.request_unsubscribe!(
      course: @course,
      email: email
    )
    assert_equal CourseInterest::RESULT_PENDING, result
    assert_equal interest, returned_interest
  end

  test 'request_unsubscribe! converts pending subscription to pending unsubscription' do
    email = 'test_pending_subscription@example.com'
    interest = @course.course_interests.create!(
      email: email,
      status: :pending_subscription
    )
    assert_no_difference('CourseInterest.count') do
      result, returned_interest = CourseInterest.request_unsubscribe!(
        course: @course,
        email: email
      )
      assert_equal CourseInterest::RESULT_PENDING, result
      assert_equal interest, returned_interest
    end
    interest.reload
    assert_equal 'pending_unsubscription', interest.status
  end

  test 'request_unsubscribe! returns not subscribed when interest is unsubscribed' do
    email = 'test_not_subscribed@example.com'
    @course.course_interests.create!(
      email: email,
      status: :unsubscribed
    )
    result, interest = CourseInterest.request_unsubscribe!(
      course: @course,
      email: email
    )
    assert_equal CourseInterest::RESULT_NOT_SUBSCRIBED, result
    assert_nil interest
  end

  test 'request_unsubscribe! updates subscribed interest to pending unsubscription' do
    email = 'test_updates_subscribed@example.com'
    interest = @course.course_interests.create!(
      email: email,
      status: :subscribed,
      subscribed_at: Time.current
    )
    assert_no_difference('CourseInterest.count') do
      result, returned_interest = CourseInterest.request_unsubscribe!(
        course: @course,
        email: email
      )
      assert_equal CourseInterest::RESULT_PENDING, result
      assert_equal interest, returned_interest
    end
    interest.reload
    assert_equal 'pending_unsubscription', interest.status
  end

  # confirm_subscription
  test 'confirm_subscription returns invalid when interest is nil' do
    result = CourseInterest.confirm_subscription(nil)
    assert_equal CourseInterest::RESULT_INVALID, result
  end

  test 'confirm_subscription returns already subscribed when already subscribed' do
    interest = @course.course_interests.create!(
      email: 'test2@example.com',
      status: :subscribed,
      subscribed_at: Time.current
    )
    result = CourseInterest.confirm_subscription(interest)
    assert_equal CourseInterest::RESULT_ALREADY_SUBSCRIBED, result
    interest.reload
    assert_equal 'subscribed', interest.status
    assert_not_nil interest.subscribed_at
  end

  test 'confirm_subscription subscribes a pending subscription' do
    interest = @course.course_interests.create!(
      email: 'test3@example.com',
      status: :pending_subscription
    )
    result = CourseInterest.confirm_subscription(interest)
    assert_equal CourseInterest::RESULT_SUBSCRIBED, result
    interest.reload
    assert_equal 'subscribed', interest.status
    assert_not_nil interest.subscribed_at
    assert_nil interest.unsubscribed_at
  end

  test 'confirm_subscription returns already unsubscribed when already unsubscribed' do
    interest = @course.course_interests.create!(
      email: 'test6@example.com',
      status: :unsubscribed,
      unsubscribed_at: Time.current
    )
    result = CourseInterest.confirm_subscription(interest)
    assert_equal CourseInterest::RESULT_ALREADY_UNSUBSCRIBED, result
    interest.reload
    assert_equal 'unsubscribed', interest.status
    assert_not_nil interest.unsubscribed_at
  end

  test 'confirm_subscription subscribes a pending unsubscription interest' do
    interest = @course.course_interests.create!(
      email: 'test7@example.com',
      status: :pending_unsubscription
    )

    result = CourseInterest.confirm_subscription(interest)

    assert_equal CourseInterest::RESULT_SUBSCRIBED, result

    interest.reload
    assert_equal 'subscribed', interest.status
    assert_not_nil interest.subscribed_at
    assert_nil interest.unsubscribed_at
  end

  # confirm_unsubscription
  test 'confirm_unsubscription returns invalid when interest is nil' do
    result = CourseInterest.confirm_unsubscription(nil)
    assert_equal CourseInterest::RESULT_INVALID, result
  end

  test 'confirm_unsubscription returns already unsubscribed when interest is already unsubscribed' do
    interest = @course.course_interests.create!(
      email: 'test8@example.com',
      status: :unsubscribed,
      unsubscribed_at: Time.current
    )

    result = CourseInterest.confirm_unsubscription(interest)

    assert_equal CourseInterest::RESULT_ALREADY_UNSUBSCRIBED, result

    interest.reload
    assert_equal 'unsubscribed', interest.status
    assert_not_nil interest.unsubscribed_at
  end

  test 'confirm_unsubscription returns already subscribed when interest is already subscribed' do
    interest = @course.course_interests.create!(
      email: 'test9@example.com',
      status: :subscribed,
      subscribed_at: Time.current
    )

    result = CourseInterest.confirm_unsubscription(interest)

    assert_equal CourseInterest::RESULT_ALREADY_SUBSCRIBED, result

    interest.reload
    assert_equal 'subscribed', interest.status
    assert_not_nil interest.subscribed_at
  end

  test 'confirm_unsubscription unsubscribes a pending subscription interest' do
    interest = @course.course_interests.create!(
      email: 'test10@example.com',
      status: :pending_subscription
    )

    result = CourseInterest.confirm_unsubscription(interest)

    assert_equal CourseInterest::RESULT_UNSUBSCRIBED, result

    interest.reload
    assert_equal 'unsubscribed', interest.status
    assert_nil interest.subscribed_at
    assert_not_nil interest.unsubscribed_at
  end

  test 'confirm_unsubscription unsubscribes a pending unsubscription interest' do
    interest = @course.course_interests.create!(
      email: 'test11@example.com',
      status: :pending_unsubscription
    )

    result = CourseInterest.confirm_unsubscription(interest)

    assert_equal CourseInterest::RESULT_UNSUBSCRIBED, result

    interest.reload
    assert_equal 'unsubscribed', interest.status
    assert_nil interest.subscribed_at
    assert_not_nil interest.unsubscribed_at
  end

  # enum
  test 'status enum defines expected values' do
    assert_equal(
      {
        'pending_subscription' => 0,
        'subscribed' => 1,
        'pending_unsubscription' => 2,
        'unsubscribed' => 3
      },
      CourseInterest.statuses
    )
  end

  test "returns emails only for subscribed interests with user email" do
    remove_existing_interest
    CourseInterest.create!(course: @course, user: @user1, status: :subscribed)
    CourseInterest.create!(course: @course, user: @user2, status: :subscribed)
    CourseInterest.create!(course: @course, email: 'test@example.com', status: :subscribed)

    result = CourseInterest.find_all_subscribed_emails(@course)
    assert_includes result, @user1.email
    assert_includes result, @user2.email
    assert_includes result, "test@example.com"
  end

  test "ignores non subscribed interests" do
    remove_existing_interest
    CourseInterest.create!(course: @course, user: @user1, status: :pending_subscription)
    CourseInterest.create!(course: @course, user: @user2, status: :unsubscribed)
    CourseInterest.create!(course: @course, email: 'test@example.com', status: :pending_unsubscription)
    result = CourseInterest.find_all_subscribed_emails(@course)
    assert_equal [], result
  end

  test "only fetches interests for given course" do
    remove_existing_interest
    other_course = courses(:two)
    CourseInterest.create!(course: @course, user: @user1, status: :subscribed)
    CourseInterest.create!(course: other_course, user: @user2, status: :subscribed)
    result = CourseInterest.find_all_subscribed_emails(@course)
    assert_equal [@user1.email], result
  end

  private

  # Remove any existing interest first
  def remove_existing_interest
    CourseInterest.where(
      course: @course,
      user: @user
    ).delete_all
  end

end
