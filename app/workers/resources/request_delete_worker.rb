module Resources
  class RequestDeleteWorker < BaseWorker
    HANDLERS = {
      'Resources::CodeRepo' => {
        'git_hub' => lambda do |resource, agent|
          agent.delete_repository(resource.full_name)
        end
      },
      'Resources::DockerRepo' => {
        'quay' => lambda do |resource, agent|
          agent.delete_repository(resource.name)
        end
      },
      'Resources::KubeNamespace' => {
        'kubernetes' => lambda do |resource, agent|
          agent.delete_namespace(resource.name)
        end
      }
    }.freeze

    def handler_for(resource)
      HANDLERS.dig resource.type, resource.provider.kind
    end

    def finalise(resource)
      resource.destroy!
    end
  end
end
