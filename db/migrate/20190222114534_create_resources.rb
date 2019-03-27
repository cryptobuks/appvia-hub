class CreateResources < ActiveRecord::Migration[5.2]
  def change
    create_table :resources, id: :uuid do |t|
      t.string :type, null: false # For Single Table Inheritance
      t.references :project, type: :uuid, null: false, foreign_key: true
      t.references :provider, type: :uuid, null: false, foreign_key: { to_table: :configured_providers }
      t.string :status, null: false
      t.string :name, null: false
      t.jsonb :metadata, null: false, default: {}

      t.string :lock_version # For optimistic locking

      t.timestamps

      t.index :type
      t.index %i[name provider_id], unique: true
    end
  end
end
