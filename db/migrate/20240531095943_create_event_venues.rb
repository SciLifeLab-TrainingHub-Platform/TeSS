class CreateEventVenues < ActiveRecord::Migration[7.0]
  def change
    create_table :event_venues do |t|
      t.references :event, null: false, foreign_key: true
      t.references :venue, null: false, foreign_key: true

      t.timestamps
    end
  end
end
