class RemoveVenueFromEvent < ActiveRecord::Migration[7.0]
  def change
    remove_column :events, :venue, :string
  end
end
