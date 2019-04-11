module IntegrationsHelper
  def config_field_title(name, spec)
    if spec
      spec['title']
    else
      name.humanize
    end
  end

  def config_field_tooltip(text)
    icon 'question-circle',
      title: text,
      data_attrs: {
        toggle: 'tooltip'
      }
  end
end
