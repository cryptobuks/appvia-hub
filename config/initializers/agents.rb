agents_config = %i[
  ecr
  quay
  kubernetes
  grafana
].each_with_object(ActiveSupport::OrderedOptions.new) do |a, h|
  h.send(
    "#{a}=",
    ActiveSupport::InheritableOptions.new(
      base_url: ENV["#{a.to_s.upcase}_AGENT_BASE_URL"],
      token: ENV["#{a.to_s.upcase}_AGENT_TOKEN"]
    )
  )
end

Rails.configuration.agents = agents_config
