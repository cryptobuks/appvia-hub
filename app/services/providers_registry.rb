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

    must_be_an_array data

    must_have_unique_ids data

    must_reference_valid_resource_types data

    config_schemas = prepare_and_validate_config_specs data

    [
      data.freeze,
      config_schemas.freeze
    ]
  end

  def must_be_an_array(data)
    raise 'Providers data must be an Array' unless data.is_a?(Array)
  end

  def must_have_unique_ids(data)
    ids = data.map { |p| p['id'] }.compact
    raise 'Provider IDs must be set and unique' if ids.size != data.size
  end

  def must_reference_valid_resource_types(data)

  end

  def prepare_and_validate_config_specs(data)
    # For each provider `config_spec`:
    # - Add certain assumed JSON Schema fields
    # - Validate that each is valid JSON Schema
    # - Try to instantiate a valid JsonSchema object
    data.each_with_object({}) do |p, _acc|
      id = p['id']
      config_spec = p['config_spec']

      config_spec['type'] = 'object'
      config_spec['additionalProperties'] = false

      _acc[id] = JsonSchema.parse!(config_spec)
    end
  end
end
