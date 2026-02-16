# frozen_string_literal: true

class CreateCoursePendingEvents < ActiveRecord::Migration[7.0]
  def change
    create_table :course_pending_events do |t|
      t.references :course, null: false, foreign_key: { on_delete: :cascade }
      # events.id is `serial` (integer), so the FK column must also be integer.
      t.references :event, null: false, type: :integer, foreign_key: { on_delete: :cascade }, index: { unique: true }

      t.timestamps
    end
  end
end
