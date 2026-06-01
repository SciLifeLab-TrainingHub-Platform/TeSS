class CourseInterest < ApplicationRecord
  belongs_to :course
  belongs_to :user, optional: true

  validate :must_have_user_or_email

  def must_have_user_or_email
    if user.blank? && email.blank?
      errors.add(:base, "User or email must be present")
    end
  end
end
