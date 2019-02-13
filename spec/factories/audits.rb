FactoryBot.define do
  factory :audit do
    auditable { nil }
    associated { nil }
    user { build(:user) }
  end
end
