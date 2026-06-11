class CourseInterest < ApplicationRecord

  # the subscription status a course_interest can have
  enum :status, {
    pending_subscription: 0,
    subscribed: 1,
    pending_unsubscription: 2,
    unsubscribed: 3
  }

  # Subscription action constants.
  ACTION_SUBSCRIBE = "subscribe".freeze
  ACTION_UNSUBSCRIBE = "unsubscribe".freeze
  ACTION_REQUEST_SUBSCRIBE = "request_subscribe".freeze
  ACTION_REQUEST_UNSUBSCRIBE = "request_unsubscribe".freeze

  # Possible outcomes returned by subscription operations.
  RESULT_INVALID = :invalid
  RESULT_SUBSCRIBED = :subscribed
  RESULT_ALREADY_SUBSCRIBED = :already_subscribed
  RESULT_ALREADY_UNSUBSCRIBED = :already_unsubscribed
  RESULT_UNSUBSCRIBED = :unsubscribed
  RESULT_NOT_SUBSCRIBED = :not_subscribed
  RESULT_PENDING = :pending

  # Constants used for generating and verifying signed IDs (token purposes)
  TOKEN_PURPOSE_SUBSCRIPTION = :subscription_confirmation
  TOKEN_PURPOSE_UNSUBSCRIPTION = :unsubscription_confirmation

  # Associations.
  belongs_to :course
  belongs_to :user, optional: true

  # Validations.
  validate :must_have_user_or_email

  # new method
  def self.subscribe!(course:, user:)
    return RESULT_INVALID unless user.present?

    interest = find_or_initialize_by(course: course, user: user)
    return RESULT_ALREADY_SUBSCRIBED if interest.subscribed?
    interest.update!(
      status: :subscribed,
      subscribed_at: Time.current,
      unsubscribed_at: nil
    )
    RESULT_SUBSCRIBED
  end

  # old method
  def self.unsubscribe!(course:, user:)
    return RESULT_INVALID unless user.present?

    interest = find_by(course: course, user: user)

    # returns RESULT_NOT_SUBSCRIBED if:
    # - record doesn’t exist
    # - OR already unsubscribed (even if record exists)
    return RESULT_NOT_SUBSCRIBED unless interest.present?
    return RESULT_NOT_SUBSCRIBED if interest.unsubscribed?

    interest.update!(
      status: :unsubscribed,
      subscribed_at: nil,
      unsubscribed_at: Time.current
    )

    RESULT_UNSUBSCRIBED
  end

  # old method
  def self.request_subscribe!(course:, email:)
    return [RESULT_INVALID, nil] if email.blank?
    email = email.to_s.strip.downcase

    interest = find_or_initialize_by(course: course, email: email)
    return [RESULT_ALREADY_SUBSCRIBED, interest] if interest.subscribed?

    interest.status = :pending_subscription
    interest.save!
    [RESULT_PENDING, interest]
  end

  # old method
  def self.request_unsubscribe!(course:, email:)
    return [RESULT_INVALID, nil] if email.blank?

    email = email.to_s.strip.downcase
    interest = find_by(course: course, email: email)

    return [RESULT_NOT_SUBSCRIBED, nil] unless interest&.subscribed?
    return [RESULT_PENDING, interest] if interest.pending_unsubscription?

    interest.update!(status: :pending_unsubscription)

    [RESULT_PENDING, interest]
  end

  def self.confirm_subscription(interest)
    return RESULT_INVALID if interest.nil?

    # already confirmed subscription
    return RESULT_ALREADY_SUBSCRIBED if interest.subscribed?

    interest.update!(
      status: :subscribed,
      subscribed_at: Time.current,
      unsubscribed_at: nil
    )
    RESULT_SUBSCRIBED
  end

  # old method
  def self.confirm_unsubscription(interest)
    return RESULT_INVALID if interest.nil?

    # If the user is NOT currently subscribed, we cannot unsubscribe them.
    return RESULT_NOT_SUBSCRIBED unless interest.subscribed?
    # If the user is already unsubscribed
    return RESULT_ALREADY_UNSUBSCRIBED if interest.unsubscribed?

    interest.update!(
      status: :unsubscribed,
      subscribed_at: nil,
      unsubscribed_at: Time.current
    )
    RESULT_UNSUBSCRIBED
  end


  private

  # Ensure either a user or email is present for every interest record.
  def must_have_user_or_email
    if user.blank? && email.blank?
      errors.add(:base, "User or email must be present")
    end
  end
end
