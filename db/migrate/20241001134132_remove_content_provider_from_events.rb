class RemoveContentProviderFromEvents < ActiveRecord::Migration[7.0]
  def change
    remove_column :events, :content_provider_id, :integer
  end
end
