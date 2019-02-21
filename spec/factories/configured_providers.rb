FactoryBot.define do
  factory :configured_provider do
    sequence :name do |n|
      "Configured Provider #{n}"
    end
    kind { ConfiguredProvider.kinds.keys.first }
  end
end
