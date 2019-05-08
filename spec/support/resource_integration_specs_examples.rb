module ResourceIntegrationSpecsExamples
  RSpec.shared_examples 'resource integration specs' do
    include_context 'time helpers'

    let! :integration do
      create :integration,
        provider_id: provider_id,
        config: integration_config
    end

    let! :provisioning_service do
      ResourceProvisioningService.new
    end

    let :agent do
      instance_double(agent_class)
    end

    before do
      expect(agent_class).to receive(:new)
        .with(**agent_initializer_params)
        .and_return(agent)

      allow(ResourceProvisioningService).to receive(:new)
        .and_return(provisioning_service)
    end

    let :dependent_type do
      nil
    end

    let :dependent_integration do
      nil
    end

    describe 'request create' do
      context 'when agent doesn\'t throw an error' do
        before do
          agent_create_method_call_success.call(agent, resource)

          if dependent_type.present?
            expect(provisioning_service).to receive(:request_dependent_create)
              .with(resource, dependent_type)
              .and_call_original

            expect(ResourceTypesService).to receive(:integrations_for)
              .with(dependent_type)
              .and_return([dependent_integration])
          end
        end

        it 'works as expected' do
          move_time_to 1.minute.from_now

          expect do
            provisioning_service.request_create resource
          end.to change(Resources::RequestCreateWorker.jobs, :size).by(1)

          expect(resource.status).to eq Resource.statuses[:pending]

          expect(resource.audits.order(:created_at).last.action).to eq 'request_create'

          move_time_to 1.minute.from_now

          Resources::RequestCreateWorker.perform_one

          updated = Resource.find resource.id

          expect(updated.name).to eq resource.name
          expect(updated.status).to eq Resource.statuses[:active]

          request_create_finished_success_expectations.call updated

          if dependent_type.present?
            expect(Resources::RequestCreateWorker.jobs.size).to eq 1
            worker = Resources::RequestCreateWorker.jobs.first

            expect(updated.children.length).to eq 1
            dependent = updated.children.first

            expect(worker['args']).to contain_exactly dependent.id

            expect(dependent.integration).to eq dependent_integration
            expect(dependent.project).to eq resource.project
            expect(dependent.name).to eq resource.name
            expect(dependent.status).to eq Resource.statuses[:pending]

            expect(dependent.audits.order(:created_at).last.action).to eq 'request_create'
          end
        end
      end

      context 'when agent throws an error' do
        before do
          agent_create_method_call_error.call(agent, resource)

          expect(provisioning_service).to receive(:request_dependent_create).never if dependent_type.present?
        end

        it 'marks the resource as failed' do
          provisioning_service.request_create resource

          Resources::RequestCreateWorker.perform_one

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

          dependent = (resource.children.first if dependent_type.present?)

          expect do
            provisioning_service.request_delete resource
          end.to change(Resources::RequestDeleteWorker.jobs, :size).by(1)

          expect(resource.status).to eq Resource.statuses[:deleting]

          expect(resource.audits.order(:created_at).last.action).to eq 'request_delete'

          move_time_to 1.minute.from_now

          Resources::RequestDeleteWorker.perform_one

          expect(Resource.exists?(resource.id)).to be false

          if dependent.present?
            expect(Resources::RequestDeleteWorker.jobs.size).to eq 1
            worker = Resources::RequestDeleteWorker.jobs.first
            expect(worker['args']).to contain_exactly dependent.id
            expect(dependent.reload.status).to eq Resource.statuses[:deleting]
          end
        end
      end

      context 'when agent throws an error' do
        before do
          agent_delete_method_call_error.call(agent, resource)
        end

        it 'marks the resource as failed' do
          provisioning_service.request_delete resource

          Resources::RequestDeleteWorker.perform_one

          updated = Resource.find resource.id

          expect(updated.status).to eq Resource.statuses[:failed]

          if dependent_type.present?
            expect(Resources::RequestDeleteWorker.jobs.size).to eq 0
            expect(resource.children.size).to eq 1
          end
        end
      end
    end
  end
end
