class AppBootstrapService
  def initialize(app, resource_provisioning_service: ResourceProvisioningService.new)
    @app = app
    @resource_provisioning_service = resource_provisioning_service
  end

  def bootstrap
    return if @app.resources.count.positive?

    git_hub_provider = ConfiguredProvider.git_hub.first

    return if git_hub_provider.blank?

    code_repo = @app.code_repos.create!(
      provider: git_hub_provider,
      name: @app.slug
    )

    @resource_provisioning_service.request_create code_repo
  end
end
