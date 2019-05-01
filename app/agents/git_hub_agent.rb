class GitHubAgent
  def initialize(app_id:, app_private_key:, app_installation_id:, org:)
    @app_id = app_id
    @app_private_key = OpenSSL::PKey::RSA.new(app_private_key.gsub('\n', "\n"))
    @app_installation_id = app_installation_id
    @org = org

    setup_client
  end

  def create_repository(name, private: false, best_practices: false)
    client = app_installation_client

    resource = client.create_repository(
      name,
      organization: @org,
      private: private,
      auto_init: best_practices
    )

    return resource unless best_practices

    # https://github.community/t5/GitHub-API-Development-and/REST-API-v3-wildcard-branch-protection/td-p/14547
    client.protect_branch(resource.full_name, 'master',
      enforce_admins: true,
      required_status_checks: {
        contexts: [],
        strict: true
      },
      required_pull_request_reviews: {
        dismiss_stale_reviews: true,
        require_code_owner_reviews: true
      })

    resource
  end

  def delete_repository(full_name)
    slug = full_name.split('/').last
    return unless app_installation_client.repository?(slug, organization: @org)

    app_installation_client.delete_repository(full_name)
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
