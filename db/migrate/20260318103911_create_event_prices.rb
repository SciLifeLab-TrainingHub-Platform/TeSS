class CreateEventPrices < ActiveRecord::Migration[7.0]
  def change
    create_table :event_prices do |t|
      t.references :event, null: false, foreign_key: true
      t.decimal :cost, precision: 10, scale: 2
      t.string :currency
      t.string :audience_type

      t.timestamps
    end
  end
end
