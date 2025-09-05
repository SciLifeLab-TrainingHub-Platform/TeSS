class AddUniqueIndexToCitiesNameAndCountryCode < ActiveRecord::Migration[7.0]
  def change
    add_index :cities, [:name, :country_code], unique: true, name: 'index_cities_on_name_and_country_code'
  end
end
