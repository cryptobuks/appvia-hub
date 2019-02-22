class GitHubAgent
  def initialize(app_id:, app_private_key:, app_installation_id:, org:)
    @app_id = app_id
    @app_private_key = OpenSSL::PKey::RSA.new(app_private_key.gsub('\n', "\n"))
    @app_installation_id = app_installation_id
    @org = org

    setup_client
  end

  def create_repository(name, private: false)
    app_installation_client.create_repository(
      name,
      private: private,
      organization: @org
    )
  end

  def delete_repository(full_name)
    app_installation_client.delete_repository full_name
  end

  private

  def setup_client
    payload = {
      iat: Time.now.to_i,
      exp: Time.now.to_i + (10 * 60), # Max is 10 mins
      iss: @app_id
    }

    jwt = JWT.encode payload, @app_private_key, 'RS256'

    @client = Octokit::Client.new bearer_token: jwt
  end

  def app_installation_client
    token = @client.create_app_installation_access_token(@app_installation_id)[:token]
    Octokit::Client.new bearer_token: token
  end
end
