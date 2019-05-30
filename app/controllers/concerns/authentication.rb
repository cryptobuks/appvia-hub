require 'uri'

module Authentication
  extend ActiveSupport::Concern

  extend Memoist

  AUTH_HEADERS = {
    subject: Rails.configuration.x.auth.sub_header,
    email: Rails.configuration.x.auth.email_header,
    name: Rails.configuration.x.auth.name_header
  }.freeze

  def require_authentication
    head(:unauthorized) && return unless current_user?
  end

  def record_last_seen!
    current_user.touch :last_seen_at if current_user? # rubocop:disable Rails/SkipsModelValidations
  end

  def current_user?
    current_user.present?
  end

  def current_user
    auth_data = auth_data_from_headers

    return nil if auth_data.blank?

    create_or_fetch_authed_user auth_data
  end
  memoize :current_user

  private

  def auth_data_from_headers
    AUTH_HEADERS.each_with_object({}) do |(k, v), acc|
      acc[k] = request.headers[v]
    end.compact
  end

  def create_or_fetch_authed_user(auth_data)
    email = auth_data[:email].presence || (
      # Without an email, we resort to checking the `subject` for a valid email
      auth_data[:subject].presence &&
        auth_data[:subject].match(URI::MailTo::EMAIL_REGEXP).to_a.first
    )

    if email.blank?
      Rails.logger.error "Failed to authenticate user: missing email in 'X-Auth-Email' or 'X-Auth-Subject' headers"
      return nil
    end

    User.find_or_create_by!(email: email) do |u|
      u.name = auth_data[:name]
      u.role = User.roles[:admin] if User.count.zero?
    end
  end
end
