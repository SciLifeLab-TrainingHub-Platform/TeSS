class CreateCoursesContentProvidersJoinTable < ActiveRecord::Migration[7.0]
  def change
    create_join_table :courses, :content_providers do |t|
      # Ensure no duplicate course-content_provider pairs
      t.index [:course_id, :content_provider_id], unique: true, name: 'index_courses_content_providers'
      # Optional reverse index for faster lookups by content_provider
      t.index [:content_provider_id, :course_id], name: 'index_content_providers_courses'
    end
  end
end
