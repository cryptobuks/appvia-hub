module ApplicationHelper
  def header_nav_item(text, path, alternate_path: nil)
    is_active = current_page? path
    is_active ||= current_page?(alternate_path) if alternate_path
    li_classes = ['nav-item']
    li_classes << 'active' if is_active

    tag.li class: li_classes do
      link_to path, class: 'nav-link' do
        safe_join(
          [text].tap do |a|
            a << tag.span(t('site-header.active'), class: 'sr-only') if is_active
          end
        )
      end
    end
  end
end
