require 'rails_helper'

RSpec.describe 'Docker Repos – ECR' do
  include_examples 'resource integration specs' do
    let(:provider_id) { 'ecr' }

    let :integration_config do
      {
        'org' => 'my_org',
        'account' => 'AWS account ID',
        'access_id' => 'access ID',
        'access_token' => 'access token',
        'region' => 'AWS region',
        'global_robot_name' => 'global robot name',
        'global_robot_access_id' => 'global robot name',
        'global_robot_token' => 'global robot token'
      }
    end

    let! :resource do
      create :docker_repo, integration: integration
    end

    let(:agent_class) { ECRAgent }
    let :agent_initializer_params do
      {
        agent_base_url: Rails.configuration.agents.ecr.base_url,
        agent_token: Rails.configuration.agents.ecr.token,
        org: integration_config['org'],
        account: integration_config['account'],
        access_id: integration_config['access_id'],
        access_token: integration_config['access_token'],
        region: integration_config['region'],
        global_robot_name: integration_config['global_robot_name']
      }
    end

    let :agent_create_response do
      double(
        spec: double(
          visibility: 'private',
          url: "http://foo.bar/#{resource.name}"
        )
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
        expect(updated.visibility).to eq agent_create_response.spec.visibility
        expect(updated.base_uri).to eq agent_create_response.spec.url
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
        expect(updated.visibility).to eq nil
        expect(updated.base_uri).to eq nil
      end
    end

    let :request_delete_before_setup_resource_state do
      lambda do |resource|
      end
    end

    let :agent_delete_method_call_success do
      lambda do |agent, resource|
        expect(agent).to receive(:delete_repository)
          .with(resource.name)
          .and_return(true)
      end
    end

    let :agent_delete_method_call_error do
      lambda do |agent, resource|
        expect(agent).to receive(:delete_repository)
          .with(resource.name)
          .and_raise('Something broked')
      end
    end
  end
end
