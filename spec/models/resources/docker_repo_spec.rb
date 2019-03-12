require 'rails_helper'

RSpec.describe Resources::DockerRepo, type: :model do
  let(:provider) { create_mocked_provider }

  subject { create :docker_repo, provider: provider }

  include_examples 'is a Resource'
end
