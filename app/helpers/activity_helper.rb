module ActivityHelper
  def activity_entry(icon, timestamp)
    tag.li class: 'list-group-item' do
      concat(tag.span(local_time_ago(timestamp), class: 'time-ago ml-2'))
      concat(icon)
      yield
    end
  end
end
