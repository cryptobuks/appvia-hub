module ApplicationHelper
  def nav_item(text, path, icon_name: nil)
    link_classes = ['nav-link', 'text-nowrap']
    is_active = current_page? path
    link_classes << 'active' if is_active

    tag.li class: 'nav-item' do
      link_to path, class: link_classes do
        concat(icon(icon_name)) if icon_name
        concat(tag.span(text))
        concat(tag.span('(current)', class: 'sr-only')) if is_active
      end
    end
  end

  def icon(name, size: '1x')
    tag.i '', class: "fas fa-#{name} fa-#{size}"
  end
end
