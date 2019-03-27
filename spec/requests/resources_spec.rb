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
end
