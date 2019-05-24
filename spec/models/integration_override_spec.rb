require 'rails_helper'

RSpec.describe IntegrationOverride, type: :model do
  subject do
    create :integration_override, integration: create_mocked_integration
  end

  describe '#project' do
    it { is_expected.to belong_to(:project) }
    it { is_expected.to have_readonly_attribute(:project_id) }
  end

  describe '#integration' do
    it { is_expected.to belong_to(:integration).class_name('Integration') }
    it { is_expected.to have_readonly_attribute(:integration_id) }
  end
end
