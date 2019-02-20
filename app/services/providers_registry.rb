class ProvidersRegistry
  extend Memoist

  attr_reader :config_schemas

  def initialize(data)
    @providers, @config_schemas = prepare_and_validate!(data)
  end

  def ids
    @providers.map { |p| p['id'] }
  end
  memoize :ids

  private

  def prepare_and_validate!(data)
    data = data.deep_dup
    config_schemas = {}

    # Must be an Array
    raise 'Providers data must be an Array' unless data.is_a?(Array)

    # Providers must have unique IDs
    ids = data.map { |p| p['id'] }.compact
    raise 'Provider IDs must be set and unique' if ids.size != data.size

    # For each provider `config_spec`:
    # - Add certain assumed JSON Schema fields
    # - Validate that each is valid JSON Schema
    # - Store the JSON Schema object
    data.each do |p|
      id = p['id']
      config_spec = p['config_spec']

      config_spec['type'] = 'object'
      config_spec['additionalProperties'] = false

      config_schemas[id] = JsonSchema.parse!(config_spec)
    end

    [
      data.freeze,
      config_schemas.freeze
    ]
  end
end
