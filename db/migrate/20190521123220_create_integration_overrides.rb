class CreateIntegrationOverrides < ActiveRecord::Migration[5.2]
  def change
    create_table :integration_overrides, id: :uuid do |t|
      t.references :project, type: :uuid, null: false, foreign_key: true
      t.references :integration, type: :uuid, null: false, foreign_key: true
      t.text :config, null: false

      t.timestamps

      t.index %i[project_id integration_id], unique: true
    end
  end
end
