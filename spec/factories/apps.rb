FactoryBot.define do
  factory :app do
    sequence :name do |n|
      "App #{n}"
    end
    sequence :slug do |n|
      "app-#{n}"
    end
  end
end
