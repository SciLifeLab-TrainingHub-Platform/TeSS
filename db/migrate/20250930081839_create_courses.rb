class CreateCourses < ActiveRecord::Migration[7.0]
  def change
    create_table :courses do |t|
      t.string :title
      t.text :description
      t.string :language
      t.text :keywords, array: true, default: []
      t.jsonb :authors, array: true, default: []
      t.jsonb :contributors, array: true, default: []
      t.string :url
      t.text :learning_outcomes
      t.text :structure_and_duration
      t.string :target_audience, array: true, default: []
      t.text :prerequisites_knowledge
      t.text :prerequisites_technical
      t.string :licensing

      t.timestamps
    end
  end
end
