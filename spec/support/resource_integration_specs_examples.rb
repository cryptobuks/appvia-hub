module ResourceIntegrationSpecsExamples
  RSpec.shared_examples 'resource integration specs' do
    include_context 'time helpers'

    let :integration do
      create :integration,
        provider_id: provider_id,
        config: integration_config
    end

    let :provisioning_service do
      ResourceProvisioningService.new
    end

    let :agent do
      instance_double(agent_class)
    end

    before do
      expect(agent_class).to receive(:new)
        .with(**agent_initializer_params)
        .and_return(agent)
    end

    describe 'request create' do
      context 'when agent doesn\'t throw an error' do
        before do
          agent_create_method_call_success.call(agent, resource)
        end

        it 'works as expected' do
          move_time_to 1.minute.from_now

          expect do
            provisioning_service.request_create resource
          end.to change(Resources::RequestCreateWorker.jobs, :size).by(1)

          expect(resource.status).to eq Resource.statuses[:pending]

          expect(resource.audits.order(:created_at).last.action).to eq 'request_create'

          Sidekiq::Worker.drain_all

          updated = Resource.find resource.id

          expect(updated.name).to eq resource.name
          expect(updated.status).to eq Resource.statuses[:active]

          request_create_finished_success_expectations.call updated
        end
      end

      context 'when agent throws an error' do
        before do
          agent_create_method_call_error.call(agent, resource)
        end

        it 'marks the resource as failed' do
          provisioning_service.request_create resource

          Sidekiq::Worker.drain_all

          updated = Resource.find resource.id

          expect(updated.name).to eq resource.name
          expect(updated.status).to eq Resource.statuses[:failed]

          request_create_finished_error_expectations.call updated
        end
      end
    end

    describe 'request_delete' do
      before do
        request_delete_before_setup_resource_state.call resource
        resource.status = Resource.statuses[:active]
        resource.save!
      end

      context 'when agent doesn\'t throw an error' do
        before do
          agent_delete_method_call_success.call(agent, resource)
        end

        it 'works as expected' do
          move_time_to 1.minute.from_now

          expect do
            provisioning_service.request_delete resource
          end.to change(Resources::RequestDeleteWorker.jobs, :size).by(1)

          expect(resource.status).to eq Resource.statuses[:deleting]

          expect(resource.audits.order(:created_at).last.action).to eq 'request_delete'

          Sidekiq::Worker.drain_all

          expect(Resource.exists?(resource.id)).to be false
        end
      end

      context 'when agent throws an error' do
        before do
          agent_delete_method_call_error.call(agent, resource)
        end

        it 'marks the resource as failed' do
          provisioning_service.request_delete resource

          Sidekiq::Worker.drain_all

          updated = Resource.find resource.id

          expect(updated.status).to eq Resource.statuses[:failed]
        end
      end
    end
  end
end
