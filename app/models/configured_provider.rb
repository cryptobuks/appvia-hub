class ConfiguredProvider < ApplicationRecord
  audited

  enum kind: PROVIDERS_REGISTRY.ids.each_with_object({}) { |id, acc| acc[id] = id }

  crypt_keeper :config,
    encryptor: :active_support,
    key: Rails.application.secrets.secret_key_base,
    salt: Rails.application.secrets.secret_salt

  validates :name, presence: true

  validates :kind, presence: true

  validates :config, presence: true

  validate :validate_config_matches_schema

  def config=(hash)
    super hash.try(:to_json)
  end

  def config
    value = super
    value.present? ? JSON.parse(value) : nil
  end

  def descriptor
    name
  end

  private

  def validate_config_matches_schema
    return if kind.blank?

    PROVIDERS_REGISTRY
      .config_schemas[kind]
      .validate!(config)
  rescue JsonSchema::AggregateError => ex
    errors.add :config, ex.to_s
  end
end
