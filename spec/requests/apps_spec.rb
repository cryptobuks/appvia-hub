require 'rails_helper'

RSpec.describe 'Apps', type: :request do
  include_context 'time helpers'

  describe 'index - GET /apps' do
    it_behaves_like 'unauthenticated not allowed' do
      before do
        get apps_path
      end
    end

    it_behaves_like 'authenticated' do
      before do
        @apps = create_list(:app, 3).sort_by(&:name)
      end

      it 'loads the apps index page' do
        get apps_path
        expect(response).to be_successful
        expect(response).to render_template(:index)
        expect(assigns(:apps)).to eq @apps
      end
    end
  end

  describe 'show - GET /apps/:id' do
    before do
      @app = create :app
    end

    it_behaves_like 'unauthenticated not allowed' do
      before do
        get app_path(@app)
      end
    end

    it_behaves_like 'authenticated' do
      let(:activity_service) { instance_double('ActivityService') }

      before do
        expect(ActivityService).to receive(:new)
          .and_return(activity_service)
        expect(activity_service).to receive(:for_app)
          .with(@app)
          .and_return([])
      end

      it 'loads the app page' do
        get app_path(@app)
        expect(response).to be_successful
        expect(response).to render_template(:show)
        expect(assigns(:app)).to eq @app
        expect(assigns(:activity)).to eq []
      end
    end
  end

  describe 'new - GET /apps/new' do
    it_behaves_like 'unauthenticated not allowed' do
      before do
        get new_app_path
      end
    end

    it_behaves_like 'authenticated' do
      it 'loads the new app page' do
        get new_app_path
        expect(response).to be_successful
        expect(response).to render_template(:new)
        expect(assigns(:app)).to be_a App
        expect(assigns(:app)).to be_new_record
      end
    end
  end

  describe 'edit - GET /apps/edit' do
    before do
      @app = create :app
    end

    it_behaves_like 'unauthenticated not allowed' do
      before do
        get edit_app_path(@app)
      end
    end

    it_behaves_like 'authenticated' do
      it 'loads the edit app page' do
        get edit_app_path(@app)
        expect(response).to be_successful
        expect(response).to render_template(:edit)
        expect(assigns(:app)).to eq @app
      end
    end
  end

  describe 'create - POST /apps' do
    let :params do
      {
        name: 'Foo',
        slug: 'foo-1',
        description: 'fooooooo'
      }
    end

    it_behaves_like 'unauthenticated not allowed' do
      before do
        post apps_path, params: { app: params }
      end
    end

    it_behaves_like 'authenticated' do
      context 'with valid params' do
        before do
          app_bootstrap_service = instance_double('AppBootstrapService')
          expect(AppBootstrapService).to receive(:new)
            .with(App)
            .and_return(app_bootstrap_service)
          expect(app_bootstrap_service).to receive(:bootstrap)
        end

        it 'creates a new App with the given params and redirects to the app page' do
          expect do
            post apps_path, params: { app: params }
            app = assigns(:app)
            expect(response).to redirect_to(app)
            expect(app).to be_persisted
            expect(app.name).to eq params[:name]
            expect(app.slug).to eq params[:slug]
            expect(app.description).to eq params[:description]
            expect(app.created_at.to_i).to eq now.to_i
          end.to change { App.count }.by(1)
        end

        it 'logs an Audit' do
          post apps_path, params: { app: params }
          app = assigns(:app)
          audit = app.audits.order(:created_at).last
          expect(audit.action).to eq 'create'
          expect(audit.user_email).to eq auth_email
          expect(audit.created_at.to_i).to eq now.to_i
        end
      end

      context 'with invalid params' do
        before do
          expect(AppBootstrapService).to receive(:new).never
        end

        it 'loads the new page with errors' do
          post apps_path, params: { app: { name: nil, slug: '1 2 3' } }
          expect(response).to be_successful
          expect(response).to render_template(:new)
          app = assigns(:app)
          expect(app).not_to be_persisted
          expect(app.errors).to_not be_empty
          expect(app.errors[:name]).to be_present
          expect(app.errors[:slug]).to be_present
        end
      end
    end
  end

  describe 'update - PUT /apps/:id' do
    before do
      @app = create :app
    end

    let :updated_params do
      {
        name: 'Updated Name',
        description: 'Updated description'
      }
    end

    it_behaves_like 'unauthenticated not allowed' do
      before do
        put app_path(@app), params: { app: updated_params }
      end
    end

    it_behaves_like 'authenticated' do
      context 'with valid params' do
        it 'updates the existing App with the given params and redirects to the app page' do
          expect do
            put app_path(@app), params: { app: updated_params }
            app = App.find @app.id
            expect(response).to redirect_to(app)
            expect(assigns(:app)).to eq app
            expect(app.name).to eq updated_params[:name]
            expect(app.description).to eq updated_params[:description]
            expect(app.updated_at.to_i).to eq now.to_i
          end.to change { App.count }.by(0)
        end

        it 'logs an Audit' do
          move_time_to 1.minute.from_now
          put app_path(@app), params: { app: updated_params }
          app = App.find @app.id
          audit = app.audits.order(:created_at).last
          expect(audit.action).to eq 'update'
          expect(audit.user_email).to eq auth_email
          expect(audit.created_at.to_i).to eq now.to_i
        end
      end

      context 'with invalid params' do
        it 'loads the edit page with errors' do
          put app_path(@app), params: { app: { name: nil } }
          expect(response).to be_successful
          expect(response).to render_template(:edit)
          app = assigns(:app)
          expect(app.errors).to_not be_empty
          expect(app.errors[:name]).to be_present
        end
      end

      it 'silently ignores changes to the slug' do
        put app_path(@app), params: { app: { slug: 'updated-slug' } }
        expect(App.exists?(slug: @app.slug)).to be true
        expect(App.exists?(slug: 'updated-slug')).to be false
      end
    end
  end

  describe 'destroy - DELETE /apps/:id' do
    before do
      @app = create :app
    end

    it_behaves_like 'unauthenticated not allowed' do
      before do
        delete app_path(@app)
      end
    end

    it_behaves_like 'authenticated' do
      it 'deletes the existing App and redirects to the apps index page' do
        expect do
          delete app_path(@app)
          expect(App.exists?(@app.id)).to be false
          expect(response).to redirect_to(apps_url)
        end.to change { App.count }.by(-1)
      end

      it 'logs an Audit' do
        move_time_to 1.minute.from_now
        delete app_path(@app)
        audit = Audit
          .auditable_finder(@app.id, App.name)
          .order(:created_at)
          .last
        expect(audit).not_to be nil
        expect(audit.action).to eq 'destroy'
        expect(audit.user_email).to eq auth_email
        expect(audit.created_at.to_i).to eq now.to_i
      end
    end
  end
end
