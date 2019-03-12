require 'rails_helper'

RSpec.describe Resources::CodeRepo, type: :model do
  let(:provider) { create_mocked_provider }

  subject { create :code_repo, provider: provider }

  include_examples 'is a Resource'
end
