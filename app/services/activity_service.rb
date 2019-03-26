class ActivityService
  DEFAULT_PAGE_SIZE = 20

  def overall
    with_defaults(Audit.all)
  end

  def for_project(project)
    with_defaults(project.own_and_associated_audits)
  end

  private

  def with_defaults(scope)
    scope
      .limit(DEFAULT_PAGE_SIZE)
      .order(created_at: :desc)
  end
end
