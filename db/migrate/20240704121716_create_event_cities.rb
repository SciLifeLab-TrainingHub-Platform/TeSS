class CreateEventCities < ActiveRecord::Migration[7.0]
  def change
    create_table :event_cities do |t|
      t.references :event, null: false, foreign_key: true
      t.references :city, null: false, foreign_key: true

      t.timestamps
    end
  end
end
