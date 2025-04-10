class MakeMoreEventFieldsMandatory < ActiveRecord::Migration[7.0]
  def up
    Event.where(language: nil).update_all(language: "English")
    Event.where(prerequisites: nil).update_all(prerequisites: "N/A")
    Event.where(target_audience: nil).update_all(target_audience: "Everyone")
    Event.where(cost_basis: nil).update_all(cost_basis: "N/A")
    # this migration does not handle the default value for content providers
    # even though in the real world it should. due to both time constraints and
    # the size of the existing data in production (small), as well as the
    # complexity of creating a 'dummy' content provider and then excluding it
    # properly from being selectable both in UI and in the API, we decided to
    # rely on the manual update of all the pre-existing records in the
    # production database. the good news is that if we somehow forget to update
    # any of the existing records, the error will come fast and be clear.

    change_column_null :events, :language, false
    change_column_null :events, :prerequisites, false
    change_column_null :events, :target_audience, false
    change_column_null :events, :cost_basis, false
  end

  def down
    change_column_null :events, :language, true
    change_column_null :events, :prerequisites, true
    change_column_null :events, :target_audience, true
    change_column_null :events, :cost_basis, true
  end

end
