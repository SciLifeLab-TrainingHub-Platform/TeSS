namespace :delete_courses do
  # to manually test this command run "rake delete_courses:delete_old"
  desc "Delete courses that are declined and older than 90 days"
  task delete_old: :environment do
    declined_courses = Course.declined.where('updated_at < ?', 90.days.ago)

    # Calls destroy on each record, which triggers callbacks like dependent: :destroy
    # ensuring associated records are handled correctly.
    deleted_count = declined_courses.destroy_all.size

    Rails.logger.info "Destroyed #{deleted_count} declined courses and their associated records."
    puts "Destroyed #{deleted_count} declined courses and their associated records."
  end
end
