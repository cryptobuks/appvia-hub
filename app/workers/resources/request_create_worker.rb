module Resources
  class RequestCreateWorker < BaseWorker
    HANDLERS = {
      'Resources::CodeRepo' => {
        'git_hub' => lambda do |resource, agent|
          result = agent.create_repository resource.name
          resource.private = result.private
          resource.full_name = result.full_name
          resource.url = result.html_url
          resource.status = Resource.statuses[:active]
          resource.save!
        end
      }
    }.freeze

    def handler_for(resource)
      HANDLERS.dig resource.type, resource.provider.kind
    end
  end
end
