# frozen_string_literal: true

class CoursePolicy < ScrapedResourcePolicy
  def clone?
    user.present?
  end
end
