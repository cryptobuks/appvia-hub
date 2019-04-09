module IntegrationsHelper
  def config_field_title(name, spec)
    if spec['properties'].key? name
      spec['properties'][name]['title']
    else
      name.humanize
    end
  end

  def config_field_tooltip(name, spec)
    return unless spec['properties'].key?(name)

    icon 'question-circle',
      title: spec['properties'][name]['description'],
      data_attrs: {
        toggle: 'tooltip'
      }
  end
end
