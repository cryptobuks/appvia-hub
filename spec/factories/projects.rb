FactoryBot.define do
  factory :project do
    sequence :name do |n|
      "Project #{n}"
    end
    sequence :slug do |n|
      "project-#{n}"
    end
  end
end
