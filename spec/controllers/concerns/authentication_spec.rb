require 'rails_helper'

describe 'Authentication Concern', type: :controller do
  controller(ActionController::Base) do
    include Authentication

    def index
      head :no_content
    end
  end

  let(:subject) { '12345' }
  let(:email) { 'foo@example.com' }
  let(:name) { 'Ms Foo' }

  def headers
    {
      'X-Auth-Subject' => subject,
      'X-Auth-Email' => email,
      'X-Auth-Username' => name
    }.compact
  end

  def hit_endpoint
    request.headers.merge! headers
    get :index
  end

  describe '#require_authentication used in before_action' do
    before do
      @controller.class.send :before_action, :require_authentication

      expect(@controller).to receive(:current_user?).and_call_original
    end

    context 'when there is a current_user detected' do
      let(:user) { instance_double(User) }

      before do
        expect(@controller).to receive(:current_user)
          .and_return(user)
      end

      it 'renders the page as expected' do
        hit_endpoint
        expect(response).to be_successful
      end
    end

    context 'when no current_user is detected' do
      before do
        expect(@controller).to receive(:current_user)
          .and_return(nil)
      end

      it 'returns a 401 Unauthorized' do
        hit_endpoint
        expect(response).to have_http_status(401)
      end
    end
  end

  describe '#record_last_seen! used in before_action' do
    before do
      @controller.class.send :before_action, :record_last_seen!
    end

    context 'when there is a current_user detected' do
      let(:user) { instance_double(User) }

      before do
        expect(@controller).to receive(:current_user)
          .and_return(user)
          .at_least(:once)
      end

      it 'updates the last_seen_at timestamp' do
        expect(user).to receive(:touch)
          .with(:last_seen_at)

        hit_endpoint
      end
    end

    context 'when no current_user is detected' do
      before do
        expect(@controller).to receive(:current_user)
          .and_return(nil)
      end

      it 'does nothing' do
        expect_any_instance_of(User).not_to receive(:touch)

        hit_endpoint
      end
    end
  end

  describe '#current_user' do
    context 'when all required headers are provided' do
      it 'creates a user account and returns it' do
        expect(User.count).to eq 0

        hit_endpoint

        current_user = @controller.current_user
        expect(current_user).not_to be nil
        expect(current_user.email).to eq email

        expect(User.count).to eq 1
        expect(current_user).to eq User.first
      end

      it 'makes the first user an admin' do
        hit_endpoint

        current_user = @controller.current_user
        expect(current_user.admin?).to be true
      end

      it 'doesn\'t make subsequent users admins' do
        create :user

        hit_endpoint

        expect(User.count).to eq 2

        current_user = @controller.current_user
        expect(current_user.admin?).to be false
      end
    end

    context 'when no email is provided' do
      let(:email) { nil }

      context 'but a subject is provided with an email address' do
        let(:subject) { 'foo_sub@example.com' }

        it 'creates a user account using the email address from the subject' do
          expect(User.count).to eq 0

          hit_endpoint

          current_user = @controller.current_user
          expect(current_user).not_to be nil
          expect(current_user.email).to eq subject

          expect(User.count).to eq 1
          expect(current_user).to eq User.first
        end
      end

      context 'but a subject is provided but not with an email address' do
        let(:subject) { '123455' }

        it 'has no current_user and creates no user accounts' do
          expect(User.count).to eq 0

          hit_endpoint

          current_user = @controller.current_user
          expect(current_user).to be nil

          expect(User.count).to eq 0
        end
      end

      context 'and neither is a subject provided' do
        let(:subject) { nil }

        it 'has no current_user and creates no user accounts' do
          expect(User.count).to eq 0

          hit_endpoint

          current_user = @controller.current_user
          expect(current_user).to be nil

          expect(User.count).to eq 0
        end
      end
    end

    context 'when the user already exists in the db' do
      let!(:user) { create :user, email: email, name: name }

      it 'loads the existing user' do
        expect(User.count).to eq 1

        hit_endpoint

        current_user = @controller.current_user
        expect(current_user).to eq User.first

        expect(User.count).to eq 1
      end
    end

    it 'memoizes the current_user method' do
      expect(User).to receive(:find_or_create_by!).once

      hit_endpoint

      # Check that it's the exact same instance
      expect(@controller.current_user).to be @controller.current_user
    end

    context 'with multiple users' do
      let!(:user_1) { create :user, email: 'foo1@example.com' }
      let!(:user_2) { create :user, email: 'foo2@example.com' }

      context 'for user 1' do
        let(:email) { user_1.email }

        it 'can load user 1 as the current_user' do
          expect(User.count).to eq 2

          hit_endpoint

          current_user = @controller.current_user
          expect(current_user).to eq user_1

          expect(User.count).to eq 2
        end
      end

      context 'for user 1' do
        let(:email) { user_2.email }

        it 'can load user 2 as the current_user' do
          expect(User.count).to eq 2

          hit_endpoint

          current_user = @controller.current_user
          expect(current_user).to eq user_2

          expect(User.count).to eq 2
        end
      end

      context 'for a new user 3' do
        let(:email) { 'foo3@example.com' }

        it 'can create a 3rd user as the current_user' do
          expect(User.count).to eq 2

          hit_endpoint

          current_user = @controller.current_user
          expect(current_user.email).to eq email

          expect(User.count).to eq 3
        end
      end
    end
  end
end
