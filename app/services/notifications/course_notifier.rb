# frozen_string_literal: true

module Notifications
  class CourseNotifier
    def initialize(course)
      @course = course
    end

    def publish
      pp course: {
        id: @course.id,
        title: @course.title,
        status: @course.course_status,
        user_id: @course.user_id
      }

      # User email
      pp user_email: @course.user&.email
      UserMailer.course_published(@course).deliver_later
      pp info: "User email enqueued for course #{@course.id}"

      # Content provider emails
      pp content_providers_count: @course.content_providers&.size

      @course.content_providers&.each do |cp|
        pp content_provider: {
          id: cp.id,
          title: cp.title,
          approval_notification_email: cp.approval_notification_email
        }

        ContentProviderMailer
          .course_content_provider_notification(@course, cp)
          .deliver_later
        pp info: "Content provider email enqueued for course #{@course.id}, content_provider_id #{cp.id}"
      end

      # Slack notification
      pp slack_payload: {
        course_id: @course.id,
        approved: @course.approved?,
        publishable: @course.respond_to?(:publishable?) ? @course.publishable? : 'N/A'
      }

      Notifications::Slack::SlackEventPublished.new(@course).call
      pp info: "Slack notification triggered for course #{@course.id}"
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
