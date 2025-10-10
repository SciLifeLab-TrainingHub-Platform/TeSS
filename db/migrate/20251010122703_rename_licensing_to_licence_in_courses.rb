class RenameLicensingToLicenceInCourses < ActiveRecord::Migration[7.0]
  def change
    rename_column :courses, :licensing, :licence
  end
end
