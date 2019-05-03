class ECRAgent
  include AgentHttpClient

  def initialize(agent_base_url:, agent_token:, account:, access_id:, access_token:, region:, global_robot_name:, org:)
    @agent_base_url = agent_base_url
    @agent_token = agent_token

    @access_id = access_id
    @access_token = access_token
    @account = account
    @global_robot_name = global_robot_name
    @organization = org
    @region = region
  end

  def create_repository(name, visibility: 'private')
    path = repo_path name
    body = {
      namespace: @organization,
      name: name,
      spec: {
        robots: [
          {
            name: @global_robot_name,
            permission: 'write'
          }
        ],
        visibility: visibility
      }
    }
    client.put do |req|
      add_access_headers req
      req.url path
      req.body = body
    end.body
  end

  def delete_repository(name)
    path = repo_path name
    client.delete do |req|
      add_access_headers req
      req.url path
    end.body
  end

  private

  def add_access_headers(req)
    req.headers['X-Auth-AccountID'] = @account
    req.headers['X-Auth-Access'] = @access_id
    req.headers['X-Auth-Token'] = @access_token
    req.headers['X-Auth-Region'] = @region
  end

  def repo_path(name)
    "registry/#{@organization}/#{name}"
  end
end
