module AppsHelper
  RESOURCE_STATUS_TO_CLASS = {
    'pending' => 'secondary',
    'active' => 'success',
    'deleting' => 'warning',
    'failed' => 'error'
  }.freeze

  def delete_app_link(app, css_class: nil)
    link_to 'Delete',
      app_path(app),
      method: :delete,
      class: css_class,
      data: {
        confirm: 'Are you sure you want to delete this app permanently?',
        title: "Delete app: #{app.slug}",
        verify: app.slug,
        verify_text: "Type '#{app.slug}' to confirm"
      },
      role: 'button'
  end

  def resource_icon_name(resource_class_or_name = nil)
    case resource_class_or_name
    when Resources::CodeRepo, 'Resources::CodeRepo', 'CodeRepo', 'Code Repo'
      'code'
    else
      'cogs'
    end
  end

  def resource_status_class(status)
    RESOURCE_STATUS_TO_CLASS[status]
  end
end
