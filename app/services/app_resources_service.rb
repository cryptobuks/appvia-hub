class AppResourcesService
  def initialize(app, resource_provisioning_service: ResourceProvisioningService.new)
    @app = app
    @resource_provisioning_service = resource_provisioning_service
  end

  def bootstrap
    return false if @app.resources.count.positive?

    git_hub_provider = ConfiguredProvider.git_hub.first

    return false if git_hub_provider.blank?

    Audit.create!(
      action: 'app_resources_bootstrap',
      auditable: @app
    )

    code_repo = @app.code_repos.create!(
      provider: git_hub_provider,
      name: @app.slug
    )

    @resource_provisioning_service.request_create code_repo

    true
  end
end
