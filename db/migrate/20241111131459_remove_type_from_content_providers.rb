class RemoveTypeFromContentProviders < ActiveRecord::Migration[7.0]
  def change
    remove_column :content_providers, :content_provider_type, :string
  end
end
