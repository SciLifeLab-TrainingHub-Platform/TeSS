class CourseInterest < ApplicationRecord

  # Email is required and must be valid format only for guest interests (no linked user);
  # registered users' emails come from the User record instead
  validates :email, presence: true,
            format: { with: URI::MailTo::EMAIL_REGEXP, message: "must be a valid email address" },
            if: -> { user_id.blank? }

  # the subscription status a course_interest can have
  # it should follow the following logic
  # for logged in user
  #  - record is created/changed status to "subscribed status"
  #  - and then changed to "unsubscribed status" when user unsubscribed
  # for non logged in user with email
  #  - record is created with pending subscription
  #  - it transition to subscribed once the confirm_subscription hits
  #  - it transition to pending_unsubscription once the request_unsubscribe hits
  #  - finally transition to unsubscribed once the confirm_unsubscription hits
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
  RESULT_UNAUTHENTICATED = :unauthenticated
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

  # only for logged in user
  # Make user subscribed no matter what, unless already subscribed
  # record transition should be as follow
  #  - nil -> "subscribed" (for new subscription)
  #  - "unsubscribed" -> "subscribed"
  #  - "subscribed" -> no status change return with RESULT_ALREADY_SUBSCRIBED
  #  - "pending_unsubscription" (should not exist but if it exist)  -> "subscribed"
  #  - "pending_subscription" (should not exist but if it exist)  -> "subscribed"
  def self.subscribe!(course:, user:)
    return RESULT_UNAUTHENTICATED unless user.present?

    interest = create_or_find_by!(course: course, user: user)
    return RESULT_ALREADY_SUBSCRIBED if interest.subscribed?
    interest.update!(
      status: :subscribed,
      subscribed_at: Time.current,
      unsubscribed_at: nil
    )
    RESULT_SUBSCRIBED
  end

  # only for logged in user
  # Make user unsubscribed unless already unsubscribed or missing
  # record transition should be as follow
  #  - "subscribed" -> "unsubscribed" (for un-subscription)
  #  - "unsubscribed" -> no status change return with RESULT_NOT_SUBSCRIBED
  #  - nil -> no status change return with RESULT_NOT_SUBSCRIBED
  #  - "pending_unsubscription" (should not exist but if it exist)  -> "unsubscribed"
  #  - "pending_subscription" (should not exist but if it exist)  -> "unsubscribed"
  def self.unsubscribe!(course:, user:)
    return RESULT_UNAUTHENTICATED unless user.present?

    interest = find_by(course: course, user: user)

    # returns RESULT_NOT_SUBSCRIBED if:
    # - record doesn't exist
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

  # only for non-logged in user
  # Force set state to pending_subscription unless already subscribed
  # record transition should be as follow
  #  - nil ->  "pending_subscription" (for new subscription)
  #  - "subscribed" -> no status change return with RESULT_ALREADY_SUBSCRIBED
  #  - "unsubscribed" -> "pending_subscription"
  #  - "pending_unsubscription" -> "pending_subscription" (if user want to resubscribe)
  #  - "pending_subscription" -> "pending_subscription" (so that new email can be sent)
  def self.request_subscribe!(course:, email:)
    return [RESULT_INVALID, nil] if email.blank?
    email = email.to_s.strip.downcase

    interest = find_or_initialize_by(course: course, email: email)
    # if interest status is already in subscribed
    return [RESULT_ALREADY_SUBSCRIBED, interest] if interest.subscribed?

    interest.status = :pending_subscription
    interest.save!
    [RESULT_PENDING, interest]
  end

  # only for non-logged in user
  # record transition should be as follow
  #  - nil ->  no status change return with RESULT_NOT_SUBSCRIBED
  #  - "subscribed" -> "pending_unsubscription"
  #  - "unsubscribed" -> no status change return with RESULT_NOT_SUBSCRIBED
  #  - "pending_unsubscription" -> "pending_unsubscription" (so that new email can be sent)
  #  - "pending_subscription" -> "pending_unsubscription" (if user want to unsubscribe without confirmation of previous subscription)
  def self.request_unsubscribe!(course:, email:)
    return [RESULT_INVALID, nil] if email.blank?

    email = email.to_s.strip.downcase
    interest = find_by(course: course, email: email)

    return [RESULT_NOT_SUBSCRIBED, nil] if interest.blank?
    return [RESULT_NOT_SUBSCRIBED, nil] if interest.unsubscribed?
    # Do not change the interest status here.
    # The unsubscribe request must be confirmed via email before the subscription is cancelled.
    # Keeping the current status prevents unauthorised users from affecting another user's
    # subscription by submitting their email address.
    [RESULT_PENDING, interest]
  end

  # only for non-logged in user
  # record transition should be as follow
  #  - nil -> no status change return with RESULT_INVALID
  #  - "subscribed" -> no status change return with RESULT_ALREADY_SUBSCRIBED
  #  - "unsubscribed" -> no status change return with RESULT_ALREADY_UNSUBSCRIBED
  #  - "pending_unsubscription" -> "subscribed" (latest intent wins)
  #  - "pending_subscription" -> "subscribed" (latest intent wins)
  def self.confirm_subscription(interest)
    return RESULT_INVALID if interest.nil?

    return RESULT_ALREADY_UNSUBSCRIBED if interest.status == "unsubscribed"
    return RESULT_ALREADY_SUBSCRIBED if interest.status == "subscribed"

    interest.update!(
      status: :subscribed,
      subscribed_at: Time.current,
      unsubscribed_at: nil
    )
    RESULT_SUBSCRIBED
  end

  # only for non-logged in user
  # record transition should be as follow
  #  - nil -> no status change return with RESULT_INVALID
  #  - "subscribed" -> "unsubscribed"
  #  - "unsubscribed" -> no status change return RESULT_ALREADY_UNSUBSCRIBED
  #  - "pending_subscription" -> "unsubscribed" (latest intent wins)
  def self.confirm_unsubscription(interest)
    return RESULT_INVALID if interest.nil?

    return RESULT_ALREADY_UNSUBSCRIBED if interest.status == "unsubscribed"

    interest.update!(
      status: :unsubscribed,
      subscribed_at: nil,
      unsubscribed_at: Time.current
    )

    RESULT_UNSUBSCRIBED
  end

  def self.subscribed_for_course(course)
    where(course: course, status: :subscribed).includes(:user)
  end

  private

  # Ensure either a user or email is present for every interest record.
  def must_have_user_or_email
    if user.blank? && email.blank?
      errors.add(:base, "User or email must be present")
    end
  end
end
