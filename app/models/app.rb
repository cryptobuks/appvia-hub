class App < ApplicationRecord
  SLUG_FORMAT_REGEX = '[a-z]+[a-z0-9\-_]*'.freeze
  SLUG_FORMAT_TEXT = 'must start with a letter and can only contain lowercase letters, numbers, hyphens, and underscores'.freeze

  include FriendlyId

  friendly_id :slug

  attr_readonly :slug

  validates :name,
    presence: true

  validates :slug,
    presence: true,
    uniqueness: true,
    format: {
      with: /\A#{SLUG_FORMAT_REGEX}\z/,
      message: SLUG_FORMAT_TEXT
    }
end
