class IntegrationOverride < ApplicationRecord
  include EncryptedConfigHashAttribute

  audited associated_with: :project

  belongs_to :project,
    -> { readonly },
    inverse_of: :integration_overrides

  belongs_to :integration,
    -> { readonly },
    inverse_of: false

  validates :integration_id,
    uniqueness: { scope: :project_id }

  attr_readonly :project_id, :integration_id

  def config_schema
    return nil if integration.blank?

    integration_schema = integration.config_schema

    overridable_properties = integration_schema.properties.select do |_k, v|
      v.data['overridable'] == true
    end

    JsonSchema.parse!(
      'properties' => overridable_properties.transform_values(&:data)
    )
  end

  def descriptor
    "For space: #{project.friendly_id} - integration: #{integration.name}"
  end
end
