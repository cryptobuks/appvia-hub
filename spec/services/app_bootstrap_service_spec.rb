require 'rails_helper'

RSpec.describe AppBootstrapService, type: :service do
  let :resource_provisioning_service do
    instance_double('ResourceProvisioningService')
  end

  let!(:app) { create :app }

  subject do
    described_class.new(
      app,
      resource_provisioning_service: resource_provisioning_service
    )
  end

  describe '#bootstrap' do
    context 'when app has some resources already' do
      let!(:provider) { create_mocked_provider }

      before do
        create :code_repo, app: app, provider: provider
      end

      it 'does not provision any resources' do
        expect(resource_provisioning_service).to receive(:request_create).never

        subject.bootstrap
      end
    end

    context 'when app has no resources yet' do
      context 'when no GitHub provider is configured yet' do
        it 'does not provision any resources' do
          expect(resource_provisioning_service).to receive(:request_create).never

          subject.bootstrap
        end
      end

      context 'when a GitHub provider is configured' do
        let!(:provider) { create_mocked_provider(kind: 'git_hub') }

        it 'provisions a GitHub repo' do
          expect(resource_provisioning_service).to receive(:request_create)

          expect do
            subject.bootstrap
          end.to change(Resources::CodeRepo, :count).by(1)
        end
      end
    end
  end
end
