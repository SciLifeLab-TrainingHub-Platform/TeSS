# app/models/concerns/course_filter.rb
module CourseFilter
  extend ActiveSupport::Concern


  # Additional filtering for courses, regarding the task with the workflow
  # This function will execute as part of search_and_filter of module Searchable
  def course_filter(user)
    pp "in course_filter"

    Proc.new do
      if user
        # If the user is an admin, include every course
        unless user.has_role?('admin')
          all_of do
            # Only include courses that are not declined
            without(:course_status, Course.course_statuses.key(Course.course_statuses[:declined]))
            any_of do
              # Show courses belonging to the user
              with(:user_id, user.id)
              # Or show approved courses
              with(:course_status, Course.course_statuses.key(Course.course_statuses[:approved]))
            end
          end
        end
      else
        # If no user is logged in, show only approved courses
        with(:course_status, Course.course_statuses.key(Course.course_statuses[:approved]))
      end
    end
  end
  module_function :course_filter
end