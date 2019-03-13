require 'rails_helper'

RSpec.describe Resources::KubeNamespace, type: :model do
  let(:provider) { create_mocked_provider }

  subject { create :kube_namespace, provider: provider }

  include_examples 'is a Resource'
end
