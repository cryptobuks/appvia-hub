Rails.application.configure do
  config.x.auth.sub_header = ENV.fetch('AUTH_SUB_HEADER', 'X-Auth-Subject')
  config.x.auth.email_header = ENV.fetch('AUTH_EMAIL_HEADER', 'X-Auth-Email')
  config.x.auth.name_header = ENV.fetch('AUTH_NAME_HEADER', 'X-Auth-Username')
  config.x.auth.logout_url = ENV.fetch('AUTH_LOGOUT_URL', '/oauth/logout')
end
