class AddCourseRefToEvents < ActiveRecord::Migration[7.0]
  def change
    add_reference :events, :course, null: true, foreign_key: true
  end
end
