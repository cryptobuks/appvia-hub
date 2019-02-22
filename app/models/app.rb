class App < ApplicationRecord
  include SluggedAttribute
  include FriendlyId

  audited

  has_many :resources,
    -> { includes :provider },
    dependent: :restrict_with_exception,
    inverse_of: :app

  has_many :code_repos,
    class_name: 'Resources::CodeRepo',
    dependent: :restrict_with_exception

  slugged_attribute :slug,
    presence: true,
    uniqueness: true,
    readonly: true

  friendly_id :slug

  validates :name, presence: true

  def descriptor
    slug
  end
end
