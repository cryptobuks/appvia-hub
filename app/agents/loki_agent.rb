class LokiAgent
  def initialize(grafana_url:)
    @grafana_url = grafana_url
  end

  def create_logging_dashboard(query_expression)
    logging_view_uri = '[' \
                         '"now-6h",' \
                         '"now",' \
                         '"Loki",' \
                         '{' \
                           '"expr":"' + query_expression + '"' \
                         '},' \
                         '{' \
                           '"ui":[true,true,true,"none"]' \
                         '}' \
                       ']'
    if @grafana_url.end_with?('/')
      @grafana_url + 'explore?left=' + CGI.escape(logging_view_uri).gsub('%2C', ',').gsub('%3A', ':')
    else
      @grafana_url + '/' + 'explore?left=' + CGI.escape(logging_view_uri).gsub('%2C', ',').gsub('%3A', ':')
    end
  end

  def delete_logging_dashboard(_name)
    true
  end
end
