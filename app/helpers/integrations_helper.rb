module IntegrationsHelper
  def config_field_title(name, spec)
    if spec
      spec['title']
    else
      name.humanize
    end
  end
end
