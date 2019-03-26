class Resource < ApplicationRecord
  include SluggedAttribute
  include AttrJson::Record

  attr_json_config default_container_attribute: :metadata

  audited associated_with: :project

  before_validation :build_name

  belongs_to :project,
    -> { readonly },
    inverse_of: :resources

  belongs_to :provider,
    -> { readonly },
    class_name: 'ConfiguredProvider',
    inverse_of: false

  enum status: {
    pending: 'pending',
    active: 'active',
    deleting: 'deleting',
    failed: 'failed'
  }

  validates :status, presence: true

  slugged_attribute :name,
    presence: true,
    uniqueness: { scope: :provider_id },
    readonly: true

  attr_readonly :project_id, :provider_id

  default_value_for :status, :pending

  def classification
    "#{self.class.model_name.human} - #{provider.kind.camelize}"
  end

  def descriptor
    "#{name} (#{classification})"
  end

  protected

  def build_name
    return if persisted? || name.blank? || project.blank?
    return if name.starts_with?(project.friendly_id)

    self.name = "#{project.friendly_id}_#{name}"
  end
end

Dir[Rails.root.join('app', 'models', 'resources', '*.rb').to_s].each do |file|
  require_dependency file
end
