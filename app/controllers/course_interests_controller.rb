class CourseInterestsController < ApplicationController

  def create
    course = Course.friendly.find(params[:course_id])
    unless current_user
      return redirect_to course_path(course),
                         alert: "You must be logged in to register interest."
    end

    result = CourseInterestService.subscribe_user!(
      course: course,
      user: current_user
    )

    if result[:status] == :error
      redirect_to course_path(course), alert: result[:message]
    else
      redirect_to course_path(course), notice: result[:message]
    end

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

    result = CourseInterestService.unsubscribe_user!(
      course: course,
      user: current_user
    )

    if result[:status] == :error
      redirect_to course_path(course), alert: result[:message]
    else
      redirect_to course_path(course), notice: result[:message]
    end

  rescue ActiveRecord::RecordNotFound
    redirect_to courses_path, alert: "Course not found"
  rescue StandardError
    redirect_to course_path(params[:course_id]), alert: "Something went wrong. Please try again."
  end

end
