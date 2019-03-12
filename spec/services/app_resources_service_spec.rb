require 'rails_helper'

RSpec.describe AppResourcesService, type: :service do
  include_context 'time helpers'

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
      before do
        provider = create_mocked_provider
        create :code_repo, app: app, provider: provider

        expect(resource_provisioning_service).to receive(:request_create).never
      end

      it 'does not provision any resources' do
        expect do
          expect(subject.bootstrap).to be false
        end.not_to change(Resource, :count)
      end

      it 'does not log an audit' do
        expect do
          subject.bootstrap
        end.not_to change(app.audits, :count)
      end
    end

    context 'when app has no resources yet' do
      context 'when no GitHub provider is configured yet' do
        before do
          expect(resource_provisioning_service).to receive(:request_create).never
        end

        it 'does not provision any resources' do
          expect do
            expect(subject.bootstrap).to be false
          end.not_to change(Resource, :count)
        end

        it 'does not log an audit' do
          expect do
            subject.bootstrap
          end.not_to change(app.audits, :count)
        end
      end

      context 'when a GitHub provider is configured' do
        before do
          create_mocked_provider(kind: 'git_hub')

          expect(resource_provisioning_service).to receive(:request_create)
        end

        it 'provisions a GitHub repo' do
          expect do
            expect(subject.bootstrap).to be true
          end.to change(Resources::CodeRepo, :count).by(1)
        end

        it 'logs an Audit' do
          expect do
            subject.bootstrap
          end.to change(app.audits, :count).by(1)

          audit = app.audits.order(:created_at).last
          expect(audit.action).to eq 'app_resources_bootstrap'
          expect(audit.created_at.to_i).to eq now.to_i
        end
      end
    end
  end
end
