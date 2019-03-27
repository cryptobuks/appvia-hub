module MockedIntegrationHelper
  RSpec.shared_context 'mocked integration helper' do
    let(:config_schema) { instance_double(JsonSchema::Schema) }

    def create_mocked_integration(provider_id: Integration.provider_ids.keys.first, config: { 'foo' => 'bar' })
      allow(PROVIDERS_REGISTRY).to receive(:config_schemas)
        .and_return(provider_id => config_schema)

      create :integration,
        provider_id: provider_id,
        config: config
    end

    before do
      allow(config_schema).to receive(:validate!)
        .and_return(true)
    end
  end
end
