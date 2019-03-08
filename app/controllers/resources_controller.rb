class ResourcesController < ApplicationController
  before_action :find_app

  # POST /apps/:app_id/resources/provision
  def provision
    result = AppResourcesService.new(@app).bootstrap

    notice = ('A new set of resources have been requested for this app' if result)

    redirect_to @app, notice: notice
  end

  private

  def find_app
    @app = App.friendly.find params[:app_id]
  end
end
