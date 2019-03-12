FactoryBot.define do
  factory :resource do
    app
    status { Resource.statuses.keys.first }
    sequence :name do |n|
      "resource-#{n}"
    end

    factory :code_repo, class: 'Resources::CodeRepo' do
    end

    factory :docker_repo, class: 'Resources::DockerRepo' do
    end
  end
end
