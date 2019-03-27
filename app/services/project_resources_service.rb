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
    git_hub_integration = Integration.git_hub.first

    return false if git_hub_integration.blank?

    code_repo = @project.code_repos.create!(
      integration: git_hub_integration,
      name: @project.slug
    )

    @resource_provisioning_service.request_create code_repo

    true
  end

  def bootstrap_docker_repo
    quay_integration = Integration.quay.first

    return false if quay_integration.blank?

    docker_repo = @project.docker_repos.create!(
      integration: quay_integration,
      name: @project.slug
    )

    @resource_provisioning_service.request_create docker_repo

    true
  end

  def bootstrap_kube_namespace
    kube_integration = Integration.kubernetes.first

    return false if kube_integration.blank?

    kube_namespace = @project.kube_namespaces.create!(
      integration: kube_integration,
      name: @project.slug
    )

    @resource_provisioning_service.request_create kube_namespace

    true
  end
end
