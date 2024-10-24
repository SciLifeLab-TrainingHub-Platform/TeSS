class DropSessions < ActiveRecord::Migration[7.0]
  def up
    drop_table :sessions
  end

  def down
    create_table :sessions do |t|
      t.string :session_id, null: false
      t.text :data
      t.timestamps
    end

    add_index :sessions, :session_id, unique: true
    add_index :sessions, :updated_at
  end
end
