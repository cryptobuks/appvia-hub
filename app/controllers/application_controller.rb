class ApplicationController < ActionController::Base
  include ErrorHandlers
  include Authentication

  before_action :require_authentication
  before_action :record_last_seen!

  helper_method :current_user
  helper_method :current_user?

  protected

  def require_admin
    redirect_to root_path, alert: 'You need to be an admin to do that' unless current_user.admin?
  end
end
