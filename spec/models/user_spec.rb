require 'rails_helper'

RSpec.describe User, type: :model do
  it 'normalises the email before validating' do
    user = create :user, email: 'Foo@BAR.coM'
    expect(user.valid?).to be true
    expect(user.email).to eq 'foo@bar.com'
  end
end
