class RemoveCostFieldsFromEvents < ActiveRecord::Migration[7.0]
  def up
    # Copy existing cost data from events to event_prices
    Event.reset_column_information

    Event.find_each do |event|
      migrated_cost = event.cost_value.present? ? event.cost_value.to_d : 0
      migrated_currency = event.cost_currency.present? ? event.cost_currency : 'SEK'
      migrated_audience = event.cost_basis.presence || 'free'

      price = EventPrice.find_or_initialize_by(
        event_id: event.id,
        cost: migrated_cost,
        currency: migrated_currency,
        audience_type: migrated_audience
      )

      if price.new_record?
        price.save!
      else
        puts "Skipping duplicate EventPrice for Event ID #{event.id}: #{migrated_cost} #{migrated_currency} #{migrated_audience}"
      end
    end

    # Remove the old columns from events
    remove_column :events, :cost_basis, :string
    remove_column :events, :cost_currency, :string
    remove_column :events, :cost_value, :decimal
  end

  def down
    add_column :events, :cost_basis, :string, null: true
    add_column :events, :cost_currency, :string
    add_column :events, :cost_value, :decimal

    Event.reset_column_information

    EventPrice.find_each do |price|
      event = Event.find(price.event_id)
      if event.cost_value.nil? && event.cost_currency.nil? && event.cost_basis.nil?
        event.update!(
          cost_value: price.cost,
          cost_currency: price.currency,
          cost_basis: price.audience_type
        )
      end
    end

    change_column_null :events, :cost_basis, false
  end
end
