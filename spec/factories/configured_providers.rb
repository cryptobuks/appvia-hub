FactoryBot.define do
  factory :configured_provider do
    sequence :name do |n|
      "Configured Provider #{n}"
    end
  end
end
