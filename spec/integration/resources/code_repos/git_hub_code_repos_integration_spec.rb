require 'rails_helper'

RSpec.describe 'Code Repos - GitHub' do
  include_examples 'resource integration specs' do
    let(:provider_id) { 'git_hub' }

    let :integration_config do
      {
        'app_id' => 'foo_app',
        'app_private_key' => 'foo_private_key',
        'app_installation_id' => 'foo_installation',
        'org' => 'foo'
      }
    end

    let! :resource do
      create :code_repo, integration: integration
    end

    let(:agent_class) { GitHubAgent }
    let(:agent_initializer_params) { integration_config.symbolize_keys }

    let :agent_create_response do
      double(
        private: true,
        full_name: "foo/#{resource.name}",
        html_url: "https://github.com/foo/#{resource.name}"
      )
    end

    let :agent_create_method_call_success do
      lambda do |agent, resource|
        expect(agent).to receive(:create_repository)
          .with(resource.name)
          .and_return(agent_create_response)
      end
    end

    let :request_create_finished_success_expectations do
      lambda do |updated|
        expect(updated.private).to eq agent_create_response.private
        expect(updated.full_name).to eq agent_create_response.full_name
        expect(updated.url).to eq agent_create_response.html_url
      end
    end

    let :agent_create_method_call_error do
      lambda do |agent, resource|
        expect(agent).to receive(:create_repository)
          .with(resource.name)
          .and_raise('Something broked')
      end
    end

    let :request_create_finished_error_expectations do
      lambda do |updated|
        expect(updated.private).to eq nil
        expect(updated.full_name).to eq nil
        expect(updated.url).to eq nil
      end
    end

    let :request_delete_before_setup_resource_state do
      lambda do |resource|
        resource.full_name = "foo/#{resource.name}"
      end
    end

    let :agent_delete_method_call_success do
      lambda do |agent, resource|
        expect(agent).to receive(:delete_repository)
          .with(resource.full_name)
          .and_return(true)
      end
    end

    let :agent_delete_method_call_error do
      lambda do |agent, resource|
        expect(agent).to receive(:delete_repository)
          .with(resource.full_name)
          .and_raise('Something broked')
      end
    end
  end
end
