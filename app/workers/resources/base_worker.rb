module Resources
  class BaseWorker
    include Sidekiq::Worker

    def perform(resource_id)
      with_resource(resource_id) do |resource|
        with_agent(resource.provider) do |agent|
          with_handler(resource) do |handler|
            handler.call resource, agent
          rescue StandardError => ex
            error_serialised = "[#{ex.class.name}] #{ex.message} - #{ex.backtrace.join(' | ')}"

            logger.error [
              "Failed to process request for resource #{resource.id}",
              "(type: #{resource.type}, provider: #{resource.provider.kind})",
              "- error: #{error_serialised}"
            ].join(' ')

            resource.failed!
          end
        end
      end
    end

    def handler_for(_resource)
      raise NotImplementedError
    end

    protected

    def with_resource(id)
      resource = Resource.find_by id: id

      if resource
        yield resource
      else
        logger.error "Could not find Resource with ID: #{id}"
      end
    end

    def with_agent(configured_provider)
      config = configured_provider.config

      agent = case configured_provider.kind
              when 'git_hub'
                GitHubAgent.new(
                  app_id: config['app_id'],
                  app_private_key: config['app_private_key'],
                  app_installation_id: config['app_installation_id'],
                  org: config['org']
                )
              end

      if agent
        yield agent
      else
        logger.error "No agent available for configured provider of kind: #{configured_provider.kind} (ID: #{configured_provider.id})"
      end
    end

    def with_handler(resource)
      handler = handler_for resource

      if handler
        yield handler
      else
        logger.error "No handler found for resource type: #{resource.type}, provider: #{resource.provider.kind}"
      end
    end
  end
end
