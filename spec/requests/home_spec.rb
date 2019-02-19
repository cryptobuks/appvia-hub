require 'rails_helper'

RSpec.describe 'Home', type: :request do
  describe 'GET /' do
    it_behaves_like 'unauthenticated not allowed' do
      before do
        get root_path
      end
    end

    it_behaves_like 'authenticated' do
      let(:activity_service) { instance_double('ActivityService') }

      before do
        expect(ActivityService).to receive(:new)
          .and_return(activity_service)
        expect(activity_service).to receive(:overall)
          .and_return([])
      end

      it 'loads the homepage' do
        get root_path
        expect(response).to be_successful
        expect(response).to render_template(:show)
        expect(assigns(:activity)).to eq []
      end
    end
  end
end
