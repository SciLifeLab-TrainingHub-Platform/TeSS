class AddAdminNotesToEvents < ActiveRecord::Migration[7.0]
  def change
    add_column :events, :admin_notes, :text
  end
end
