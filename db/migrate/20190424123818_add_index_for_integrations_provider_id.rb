class AddIndexForIntegrationsProviderId < ActiveRecord::Migration[5.2]
  def change
    add_index :integrations, :provider_id
  end
end
