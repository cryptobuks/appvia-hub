class ResourceTypesService
  class UnknownResourceType < StandardError
    attr_reader :id

    def initialize(message = nil, id: nil)
      @id = id
      super(message)
    end
  end

  class << self
    extend Memoist

    def all
      [
        {
          id: 'CodeRepo',
          class: 'Resources::CodeRepo',
          name: 'Code Repositories',
          providers: %w[git_hub].freeze
        },
        {
          id: 'DockerRepo',
          class: 'Resources::DockerRepo',
          name: 'Docker Repositories',
          providers: %w[quay].freeze
        },
        {
          id: 'KubeNamespace',
          class: 'Resources::KubeNamespace',
          name: 'Kubernetes Namespaces',
          providers: %w[kubernetes].freeze
        }
      ].map(&:freeze).freeze
    end
    memoize :all

    def get(id)
      entry = all.find { |e| e[:id] == id }

      raise UnknownResourceType.new("Unknown resource type: #{id}", id: id) if entry.blank?

      entry
    end

    def integrations_for(id)
      entry = get id

      Integration
        .where(provider_id: entry[:providers])
        .order(:created_at)
    end
  end
end
