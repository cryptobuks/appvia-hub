class User < ApplicationRecord
  audited

  validates :email,
    presence: true,
    uniqueness: true

  before_validation :normalise_email

  def descriptor
    email
  end

  private

  def normalise_email
    self.email = email.presence.try(:downcase)
  end
end
