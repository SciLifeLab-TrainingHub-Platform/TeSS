class RemoveCityStringFromEventTable < ActiveRecord::Migration[7.0]
  def change
    remove_column :events, :city, :string
  end
end
