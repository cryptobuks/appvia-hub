module ApplicationHelper
  def show_requires_setup?
    controller.controller_name != 'integrations' &&
      Integration.count.zero?
  end

  def icon(name, size: '1x', title: nil, data_attrs: nil)
    tag.i '', class: "fas fa-#{name} fa-#{size}", title: title, data: data_attrs
  end

  def brand_icon(name, size: '1x', title: nil, data_attrs: nil)
    tag.i '', class: "fab fa-#{name} fa-#{size}", title: title, data: data_attrs
  end

  def icon_with_tooltip(text, icon_name: 'question-circle')
    icon icon_name,
      title: text,
      data_attrs: {
        toggle: 'tooltip'
      }
  end

  def label_with_tooltip(label, tooltip_text)
    # rubocop:disable Rails/OutputSafety
    raw(
      [
        label,
        icon_with_tooltip(tooltip_text)
      ].join(' ')
    )
    # rubocop:enable Rails/OutputSafety
  end
end
