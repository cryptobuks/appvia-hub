require 'rails_helper'

RSpec.describe 'Project resources', type: :request do
  include_context 'time helpers'

  describe 'provision - POST /projects/:project_id/resources/provision' do
    before do
      @project = create :project
    end

    it_behaves_like 'unauthenticated not allowed' do
      before do
        post provision_project_resources_path(@project)
      end
    end

    it_behaves_like 'authenticated' do
      before do
        project_bootstrap_service = instance_double('ProjectResourcesService')
        expect(ProjectResourcesService).to receive(:new)
          .with(@project)
          .and_return(project_bootstrap_service)
        expect(project_bootstrap_service).to receive(:bootstrap)
      end

      it 'calls the ProjectResourcesService as expected and redirects to the project page' do
        post provision_project_resources_path(@project)
        expect(response).to redirect_to(@project)
      end
    end
  end

  describe 'destroy - DELETE /projects/:project_id/resources/:id' do
    let!(:project) { create :project }

    let(:integration) { create_mocked_integration }

    let! :resource do
      create :code_repo, project: project, integration: integration
    end

    let :resource_provisioning_service do
      instance_double('ResourceProvisioningService')
    end

    before do
      allow(ResourceProvisioningService).to receive(:new)
        .and_return(resource_provisioning_service)
    end

    it_behaves_like 'unauthenticated not allowed' do
      before do
        expect(resource_provisioning_service).to receive(:request_delete).never
        delete project_resource_path(project, resource)
      end
    end

    it_behaves_like 'authenticated' do
      it 'requests deletion of the resource' do
        expect(resource_provisioning_service).to receive(:request_delete)
          .with(resource)

        expect do
          delete project_resource_path(project, resource)
        end.not_to change(Resource, :count)

        expect(response).to redirect_to(project_url(project))
      end
    end
  end
end
