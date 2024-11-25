class AddApprovedEventsCountToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :approved_events_count, :integer, default: 0, null: false
  end
end
