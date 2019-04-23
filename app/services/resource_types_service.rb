class ResourceTypesService
  class << self
    extend Memoist

    def all
      [
        {
          id: 'CodeRepo',
          name: 'Code Repositories',
          providers: %w[git_hub].freeze
        },
        {
          id: 'DockerRepo',
          name: 'Docker Repositories',
          providers: %w[quay].freeze
        },
        {
          id: 'KubeNamespace',
          name: 'Kubernetes Namespaces',
          providers: %w[kubernetes].freeze
        }
      ].map(&:freeze).freeze
    end
    memoize :all
  end
end
