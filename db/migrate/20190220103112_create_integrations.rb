class CreateIntegrations < ActiveRecord::Migration[5.2]
  def change
    create_table :integrations, id: :uuid do |t|
      t.string :name, null: false
      t.string :provider_id, null: false
      t.text :config, null: false

      t.timestamps
    end
  end
end
