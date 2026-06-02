class CourseInterest < ApplicationRecord
  belongs_to :course
  belongs_to :user, optional: true

  validate :must_have_user_or_email

  def self.register!(course:, user:)
    interest = find_or_initialize_by(course: course, user: user)
    interest.subscribed_at = Time.current
    interest.unsubscribed_at = nil
    interest.save!
  end

  def self.unregister!(course:, user:)
    interest = find_by(course: course, user: user)
    return :not_found unless interest

    interest.update!(
      subscribed_at: nil,
      unsubscribed_at: Time.current
    )
    :ok
  end

  private
  def must_have_user_or_email
    if user.blank? && email.blank?
      errors.add(:base, "User or email must be present")
    end
  end
end
