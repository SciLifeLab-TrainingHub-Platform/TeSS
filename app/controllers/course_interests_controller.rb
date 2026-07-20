class CourseInterestsController < ApplicationController

  def create
    course = Course.friendly.find(params[:course_id])

    result = CourseInterestService.subscribe_user!(
      course: course,
      user: current_user
    )

    if result[:status] == :ok
      redirect_to course_path(course), notice: result[:message]
    else
      redirect_to course_path(course), alert: result[:message]
    end

  rescue ActiveRecord::RecordNotFound
    redirect_to courses_path, alert: "Course not found"
  rescue StandardError => e
    Rails.logger.error "Course interest creation error: #{e.class} - #{e.message}"
    redirect_to course_path(params[:course_id]), alert: "Something went wrong. Please try again."
  end

  def destroy
    course = Course.friendly.find(params[:course_id])

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
  rescue StandardError => e
    Rails.logger.error "Course interest destroy error: #{e.class} - #{e.message}"
    redirect_to course_path(params[:course_id]), alert: "Something went wrong. Please try again."
  end
end
