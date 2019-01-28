class User < ApplicationRecord
  validates :email,
    presence: true,
    uniqueness: true

  before_validation :normalise_email

  private

  def normalise_email
    self.email = email.presence.try(:downcase)
  end
end
