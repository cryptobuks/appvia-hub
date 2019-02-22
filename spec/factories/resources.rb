FactoryBot.define do
  factory :resource do
    app
    status { Resource.statuses.keys.first }
    sequence :name do |n|
      "resource-#{n}"
    end

    factory :code_repo, class: 'Resources::CodeRepo' do
    end
  end
end
