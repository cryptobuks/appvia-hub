require 'rails_helper'

RSpec.describe 'Home', type: :request do
  describe 'GET /' do
    it_behaves_like 'unauthenticated not allowed' do
      before do
        get root_path
      end
    end

    it_behaves_like 'authenticated' do
      it 'loads the homepage' do
        get root_path
        expect(response).to be_successful
        expect(response).to render_template(:show)
      end
    end
  end
end
