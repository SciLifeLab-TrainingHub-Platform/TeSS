class CreateEventTopics < ActiveRecord::Migration[7.0]
  def change
    create_table :event_topics do |t|
      t.references :event, null: false, foreign_key: true
      t.references :topic, null: false, foreign_key: true

      t.timestamps
    end
  end
end
