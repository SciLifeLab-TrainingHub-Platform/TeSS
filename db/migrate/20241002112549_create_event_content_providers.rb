class CreateEventContentProviders < ActiveRecord::Migration[7.0]
  def change
    create_table :event_content_providers do |t|
      t.references :event, null: false, foreign_key: true
      t.references :content_provider, null: false, foreign_key: true

      t.timestamps
    end
  end
end
