# frozen_string_literal: true

module Notifications
  class CourseNotifier
    def initialize(course)
      @course = course
    end

    def publish
      UserMailer.course_published(@course).deliver_later
      @course.content_providers&.each do |cp|
        ContentProviderMailer.course_content_provider_notification(@course, cp).deliver_later
      end
    end

    def review
      AdminMailer.review_course(@course).deliver_later
      UserMailer.course_submitted(@course).deliver_later
    end

    def reset_status_and_notify_admin(current_user)
      return unless @course.course_status == Course.course_statuses.key(Course.course_statuses[:revisions_required])
      return unless @course.user_id == current_user.id

      @course.update_column(:course_status, Course.course_statuses[:awaiting_review])
      AdminMailer.course_updated_by_user(@course).deliver_later
    end
  end
end
