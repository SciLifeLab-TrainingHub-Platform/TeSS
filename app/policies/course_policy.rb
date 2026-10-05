# frozen_string_literal: true

class CoursePolicy < ScrapedResourcePolicy
  def clone?
    manage?
  end
end
