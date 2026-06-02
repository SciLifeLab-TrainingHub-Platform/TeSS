class CourseInterestsController < ApplicationController

  def create
    course = Course.friendly.find(params[:course_id])
    unless current_user
      redirect_to course_path(course), alert: "You must be logged in to register interest."
      return
    end
    CourseInterest.register!(course: course, user: current_user)
    redirect_to course_path(course), notice: "Interest registered successfully"
  rescue ActiveRecord::RecordNotFound
    redirect_to courses_path, alert: "Course not found"
  rescue StandardError
    redirect_to course_path(params[:course_id]), alert: "Something went wrong. Please try again."
  end

  def destroy
    course = Course.friendly.find(params[:course_id])

    unless current_user
      return redirect_to course_path(course),
                         alert: "You must be logged in to unsubscribe."
    end

    result = CourseInterest.unregister!(course: course, user: current_user)

    case result
    when :ok
      redirect_to course_path(course), notice: "You have unsubscribed successfully"
    when :not_found
      redirect_to course_path(course), alert: "You are not subscribed to this course"
    else
      redirect_to course_path(course), alert: "Something went wrong. Please try again."
    end

  rescue ActiveRecord::RecordNotFound
    redirect_to courses_path, alert: "Course not found"
  rescue StandardError => e
    redirect_to courses_path, alert: e.message
  end
end
