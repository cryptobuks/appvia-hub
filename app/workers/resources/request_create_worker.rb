module Resources
  class RequestCreateWorker < BaseWorker
    HANDLERS = {
      'Resources::CodeRepo' => {
        'git_hub' => lambda do |resource, agent|
          enforce_best_practices = resource.integration.config['enforce_best_practices']
          result = agent.create_repository resource.name, best_practices: enforce_best_practices
          resource.private = result.private
          resource.full_name = result.full_name
          resource.url = result.html_url
          true
        end
      },
      'Resources::DockerRepo' => {
        'quay' => lambda do |resource, agent|
          result = agent.create_repository resource.name
          resource.visibility = result.spec.visibility
          resource.base_uri = result.spec.url
          true
        end
      },
      'Resources::KubeNamespace' => {
        'kubernetes' => lambda do |resource, agent|
          agent.create_namespace resource.name
          true
        end
      }
    }.freeze

    def handler_for(resource)
      HANDLERS.dig resource.type, resource.integration.provider_id
    end

    def finalise(resource)
      resource.status = Resource.statuses[:active]
      resource.save!
    end
  end
end
