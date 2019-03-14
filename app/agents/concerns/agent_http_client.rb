module AgentHttpClient
  extend ActiveSupport::Concern

  extend Memoist

  # Expects the following instance variables to be set:
  # - @agent_base_url
  # - @agent_token
  included do
    attr_reader :agent_base_url, :agent_token
  end

  def client
    Faraday.new(agent_base_url) do |c|
      c.request :oauth2, agent_token, token_type: :bearer
      c.request :json

      c.response :logger, ::Logger.new(STDOUT), bodies: true if Rails.env.development?

      c.response :raise_error
      c.response :json,
                 content_type: /\bjson$/,
                 parser_options: { object_class: OpenStruct }

      c.options.open_timeout = 1.minute.to_i
      c.options.timeout = 10.minutes.to_i

      c.adapter :typhoeus, forbid_reuse: true
    end
  end
  memoize :client
end
