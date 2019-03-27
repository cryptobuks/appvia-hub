class ProjectResourcesService
  def initialize(project, resource_provisioning_service: ResourceProvisioningService.new)
    @project = project
    @resource_provisioning_service = resource_provisioning_service
  end

  def bootstrap
    return false if @project.resources.count.positive?

    Audit.create!(
      action: 'project_resources_bootstrap',
      auditable: @project
    )

    bootstrap_code_repo &&
      bootstrap_docker_repo &&
      bootstrap_kube_namespace
  end

  private

  def bootstrap_code_repo
    git_hub_provider = ConfiguredProvider.git_hub.first

    return false if git_hub_provider.blank?

    code_repo = @project.code_repos.create!(
      provider: git_hub_provider,
      name: @project.slug
    )

    @resource_provisioning_service.request_create code_repo

    true
  end

  def bootstrap_docker_repo
    quay_provider = ConfiguredProvider.quay.first

    return false if quay_provider.blank?

    docker_repo = @project.docker_repos.create!(
      provider: quay_provider,
      name: @project.slug
    )

    @resource_provisioning_service.request_create docker_repo

    true
  end

  def bootstrap_kube_namespace
    kube_provider = ConfiguredProvider.kubernetes.first

    return false if kube_provider.blank?

    kube_namespace = @project.kube_namespaces.create!(
      provider: kube_provider,
      name: @project.slug
    )

    @resource_provisioning_service.request_create kube_namespace

    true
  end
end
