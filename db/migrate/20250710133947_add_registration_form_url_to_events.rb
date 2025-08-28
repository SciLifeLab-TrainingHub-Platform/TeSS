class AddRegistrationFormUrlToEvents < ActiveRecord::Migration[7.0]
  def change
    add_column :events, :registration_form_url, :string
  end
end
