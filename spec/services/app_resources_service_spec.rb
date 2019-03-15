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
    shared_examples 'logs an audit for app_resources_bootstrap' do
      it 'logs an audit for app_resources_bootstrap' do
        expect do
          subject.bootstrap
        end.to change(app.audits, :count).by(1)

        audit = app.audits.order(:created_at).last
        expect(audit.action).to eq 'app_resources_bootstrap'
        expect(audit.created_at.to_i).to eq now.to_i
      end
    end

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
      context 'when no providers are configured yet' do
        before do
          expect(resource_provisioning_service).to receive(:request_create).never
        end

        it 'does not provision any resources' do
          expect do
            expect(subject.bootstrap).to be false
          end.not_to change(Resource, :count)
        end

        include_examples 'logs an audit for app_resources_bootstrap'
      end

      context 'when the necessary providers are configured' do
        before do
          create_mocked_provider(kind: 'git_hub')
          create_mocked_provider(kind: 'quay')
          create_mocked_provider(kind: 'kubernetes')

          expect(resource_provisioning_service).to receive(:request_create)
            .exactly(3)
            .times
        end

        it 'provisions a GitHub repo, Quay repo and Kube namespace' do
          expect(Resources::CodeRepo.count).to be 0
          expect(Resources::DockerRepo.count).to be 0
          expect(Resources::KubeNamespace.count).to be 0

          expect do
            expect(subject.bootstrap).to be true
          end.to change(Resource, :count).by(3)

          expect(Resources::CodeRepo.count).to be 1
          expect(Resources::DockerRepo.count).to be 1
          expect(Resources::KubeNamespace.count).to be 1
        end

        include_examples 'logs an audit for app_resources_bootstrap'
      end
    end
  end
end
