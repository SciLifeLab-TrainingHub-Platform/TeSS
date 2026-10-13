# frozen_string_literal: true

namespace :delete_courses do
  # To manually run this command:
  # rake delete_courses:delete_old
  desc 'Delete courses that are declined and older than 90 days'

  task delete_old: :environment do
    declined_courses = Course.declined.where('updated_at < ?', 90.days.ago)

    # Calls destroy on each record, triggering callbacks like dependent: :destroy
    # and ensuring associated records are handled correctly.
    deleted_count = declined_courses.destroy_all.size

    Rails.logger.info "Destroyed #{deleted_count} declined courses and their associated records."
  end
end
