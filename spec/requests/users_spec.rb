require 'rails_helper'

RSpec.describe 'Users', type: :request do
  describe 'index - GET /users' do
    it_behaves_like 'unauthenticated not allowed' do
      before do
        get users_path
      end
    end

    it_behaves_like 'authenticated' do
      before do
        create_list :user, 2
      end

      let :total_users do
        3 # Taking into account the current_user
      end

      it 'loads the users index page' do
        get users_path
        expect(response).to be_successful
        expect(response).to render_template(:index)
        expect(assigns(:users).size).to eq total_users
      end
    end
  end
end
