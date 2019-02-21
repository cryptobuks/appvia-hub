PROVIDERS_REGISTRY = ProvidersRegistry.new(
  YAML.safe_load(
    Rails.root.join('config', 'providers.yml').read
  )
)
