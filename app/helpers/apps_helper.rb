module AppsHelper
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
end
