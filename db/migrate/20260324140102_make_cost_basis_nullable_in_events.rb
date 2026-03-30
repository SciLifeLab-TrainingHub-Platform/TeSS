class MakeCostBasisNullableInEvents < ActiveRecord::Migration[7.0]
  def change
    change_column :events, :cost_basis, :string, null: true
  end
end
