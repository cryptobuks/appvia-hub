class CreateConfiguredProviders < ActiveRecord::Migration[5.2]
  def change
    create_table :configured_providers, id: :uuid do |t|
      t.string :name, null: false
      t.string :kind, null: false
      t.text :config, null: false

      t.timestamps
    end
  end
end
