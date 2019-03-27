module ProjectsHelper
  RESOURCE_STATUS_TO_CLASS = {
    'pending' => 'secondary',
    'active' => 'success',
    'deleting' => 'warning',
    'failed' => 'danger'
  }.freeze

  def delete_project_link(project, css_class: nil)
    link_to 'Delete',
      project_path(project),
      method: :delete,
      class: css_class,
      data: {
        confirm: 'Are you sure you want to delete this project permanently?',
        title: "Delete project: #{project.slug}",
        verify: project.slug,
        verify_text: "Type '#{project.slug}' to confirm"
      },
      role: 'button'
  end

  def resource_icon(resource_class_or_name = nil)
    case resource_class_or_name
    when Resources::CodeRepo, 'Resources::CodeRepo', 'CodeRepo'
      icon 'code'
    when Resources::DockerRepo, 'Resources::DockerRepo', 'DockerRepo'
      brand_icon 'docker'
    when Resources::KubeNamespace, 'Resources::KubeNamespace', 'KubeNamespace'
      icon 'cloud'
    else
      icon 'cogs'
    end
  end

  def resource_status_class(status)
    RESOURCE_STATUS_TO_CLASS[status]
  end
end
