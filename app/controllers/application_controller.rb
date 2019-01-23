class ApplicationController < ActionController::Base
  include Authentication

  before_action :require_authentication
  before_action :record_last_seen!

  helper_method :current_user
end
