module Resources
  class RequestCreateWorker < BaseWorker
    HANDLERS = {
      'Resources::CodeRepo' => {
        'git_hub' => lambda do |resource, agent|
          result = agent.create_repository resource.name
          resource.private = result.private
          resource.full_name = result.full_name
          resource.url = result.html_url
          true
        end
      },
      'Resources::DockerRepo' => {
        'quay' => lambda do |resource, agent|
          result = agent.create_repository resource.name
          resource.base_uri = result.base_uri
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
      HANDLERS.dig resource.type, resource.provider.kind
    end

    def finalise(resource)
      resource.status = Resource.statuses[:active]
      resource.save!
    end
  end
end
