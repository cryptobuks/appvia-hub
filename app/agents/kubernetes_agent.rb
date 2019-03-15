class KubernetesAgent
  def initialize(api_url:, token:)
    @api_url = api_url
    @token = token
  end

  def create_namespace(name)
    # TODO
  end

  def delete_namespace(name)
    # TODO
  end
end
