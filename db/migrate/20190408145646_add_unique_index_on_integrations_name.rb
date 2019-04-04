class AddUniqueIndexOnIntegrationsName < ActiveRecord::Migration[5.2]
  def change
    add_index :integrations, :name, unique: true
  end
end
