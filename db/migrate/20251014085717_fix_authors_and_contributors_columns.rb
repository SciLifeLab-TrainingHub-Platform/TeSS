class FixAuthorsAndContributorsColumns < ActiveRecord::Migration[7.0]
  def change
    remove_column :courses, :authors
    remove_column :courses, :contributors

    add_column :courses, :authors, :jsonb, default: []
    add_column :courses, :contributors, :jsonb, default: []
  end
end
