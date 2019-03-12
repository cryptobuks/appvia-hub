module MockedConfiguredProviderHelper
  RSpec.shared_context 'mocked configured provider helper' do
    let(:config_schema) { instance_double(JsonSchema::Schema) }

    def create_mocked_provider(kind: ConfiguredProvider.kinds.keys.first, config: { 'foo' => 'bar' })
      allow(PROVIDERS_REGISTRY).to receive(:config_schemas)
        .and_return(kind => config_schema)

      create :configured_provider,
        kind: kind,
        config: config
    end

    before do
      allow(config_schema).to receive(:validate!)
        .and_return(true)
    end
  end
end
