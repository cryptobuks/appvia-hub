module ProjectsHelper
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
end
