require 'rails_helper'

RSpec.describe 'App resources', type: :request do
  include_context 'time helpers'

  describe 'provision - POST /apps/:app_id/resources/provision' do
    before do
      @app = create :app
    end

    it_behaves_like 'unauthenticated not allowed' do
      before do
        post provision_app_resources_path(@app)
      end
    end

    it_behaves_like 'authenticated' do
      before do
        app_bootstrap_service = instance_double('AppResourcesService')
        expect(AppResourcesService).to receive(:new)
          .with(@app)
          .and_return(app_bootstrap_service)
        expect(app_bootstrap_service).to receive(:bootstrap)
      end

      it 'calls the AppResourcesService as expected and redirects to the app page' do
        post provision_app_resources_path(@app)
        expect(response).to redirect_to(@app)
      end
    end
  end
end
