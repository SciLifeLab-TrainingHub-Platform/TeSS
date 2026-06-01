class CourseInterestsController < ApplicationController

  def create

    pp "in course_interest controller create action"
    # logged-in subscribe
  end

  def destroy
    # logged-in unsubscribe
  end

  # guest flow (custom routes)
  def subscribe_as_guest
  end

  def request_unsubscribe_email
  end

  def confirm_subscription
  end

  def confirm_unsubscribe
  end

end

