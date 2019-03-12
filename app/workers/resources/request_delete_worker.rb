module Resources
  class RequestDeleteWorker < BaseWorker
    HANDLERS = {
      'Resources::CodeRepo' => {
        'git_hub' => lambda do |resource, agent|
          if agent.delete_repository(resource.full_name)
            resource.destroy!
          else
            resource.failed!
          end
        end
      }
    }.freeze

    def handler_for(resource)
      HANDLERS.dig resource.type, resource.provider.kind
    end
  end
end
