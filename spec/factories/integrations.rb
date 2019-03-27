FactoryBot.define do
  factory :integration do
    sequence :name do |n|
      "Integration #{n}"
    end
  end
end
