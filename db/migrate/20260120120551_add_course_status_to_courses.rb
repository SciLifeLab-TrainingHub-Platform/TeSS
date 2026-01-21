class AddCourseStatusToCourses < ActiveRecord::Migration[7.0]
  def change
    add_column :courses, :course_status, :integer, default: 0, null: false
    add_index  :courses, :course_status
  end
end
