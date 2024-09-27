class AddApplicationDeadlineToEvents < ActiveRecord::Migration[7.0]
  def change
    add_column :events, :application_deadline, :datetime
  end
end
