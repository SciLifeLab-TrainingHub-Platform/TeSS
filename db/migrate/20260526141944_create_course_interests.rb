class CreateCourseInterests < ActiveRecord::Migration[7.0]
  def change
    create_table :course_interests do |t|
      t.references :course, null: false, foreign_key: true
      t.references :user, null: true, foreign_key: true
      t.string :email

      t.datetime :subscribed_at, null: true
      t.datetime :unsubscribed_at, null: true

      t.timestamps
    end
    add_index :course_interests, :email
    add_index :course_interests, [:course_id, :user_id]
  end
end
