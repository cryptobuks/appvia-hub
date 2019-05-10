class CreateHashRecords < ActiveRecord::Migration[5.2]
  def change
    create_table :hash_records, id: :uuid do |t|
      t.string :slug, null: false
      t.json :data, null: false, default: {}

      t.timestamps

      t.index :slug, unique: true
    end
  end
end
