namespace :delete_events do
  desc "Delete events that are declined and older than 30 days"
  task delete_old: :environment do
    # declined_events = Event.declined.where('updated_at < ?', 30.days.ago)
    declined_events = Event.declined.where('updated_at < ?', 5.minutes.ago)
    # Calls destroy on each record, which triggers callbacks like dependent: :destroy
    # ensuring associated records are handled correctly.
    deleted_count = declined_events.destroy_all.size

    Rails.logger.info "Destroyed #{deleted_count} declined events and their associated records."
    puts "Destroyed #{deleted_count} declined events and their associated records."
  end
end
