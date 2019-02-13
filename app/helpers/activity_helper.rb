module ActivityHelper
  def activity_entry(icon_name, timestamp)
    tag.li class: 'list-group-item' do
      concat(tag.span(local_time_ago(timestamp), class: 'time-ago'))
      concat(icon(icon_name))
      yield
    end
  end
end
