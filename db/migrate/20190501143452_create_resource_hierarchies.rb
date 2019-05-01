class CreateResourceHierarchies < ActiveRecord::Migration[5.2]
  # rubocop:disable Rails/CreateTableWithTimestamps
  def change
    create_table :resource_hierarchies, id: false do |t|
      t.uuid :ancestor_id, null: false
      t.uuid :descendant_id, null: false
      t.integer :generations, null: false
    end

    add_index :resource_hierarchies, %i[ancestor_id descendant_id generations],
      unique: true,
      name: 'resource_anc_desc_idx'

    add_index :resource_hierarchies, [:descendant_id],
      name: 'resource_desc_idx'
  end
  # rubocop:enable Rails/CreateTableWithTimestamps
end
