class AppResourcesService
  def initialize(app, resource_provisioning_service: ResourceProvisioningService.new)
    @app = app
    @resource_provisioning_service = resource_provisioning_service
  end

  def bootstrap
    return false if @app.resources.count.positive?

    Audit.create!(
      action: 'app_resources_bootstrap',
      auditable: @app
    )

    bootstrap_code_repo &&
      bootstrap_docker_repo &&
      bootstrap_kube_namespace
  end

  private

  def bootstrap_code_repo
    git_hub_provider = ConfiguredProvider.git_hub.first

    return false if git_hub_provider.blank?

    code_repo = @app.code_repos.create!(
      provider: git_hub_provider,
      name: @app.slug
    )

    @resource_provisioning_service.request_create code_repo

    true
  end

  def bootstrap_docker_repo
    quay_provider = ConfiguredProvider.quay.first

    return false if quay_provider.blank?

    docker_repo = @app.docker_repos.create!(
      provider: quay_provider,
      name: @app.slug
    )

    @resource_provisioning_service.request_create docker_repo

    true
  end

  def bootstrap_kube_namespace
    kube_provider = ConfiguredProvider.kubernetes.first

    return false if kube_provider.blank?

    kube_namespace = @app.kube_namespaces.create!(
      provider: kube_provider,
      name: @app.slug
    )

    @resource_provisioning_service.request_create kube_namespace

    true
  end
end
