class AddParentIdToResources < ActiveRecord::Migration[5.2]
  def change
    add_column :resources, :parent_id, :uuid, index: true
  end
end
