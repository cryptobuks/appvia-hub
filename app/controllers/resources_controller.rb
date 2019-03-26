class ResourcesController < ApplicationController
  before_action :find_project

  # POST /projects/:project_id/resources/provision
  def provision
    result = ProjectResourcesService.new(@project).bootstrap

    notice = ('A new set of resources have been requested for this project' if result)

    redirect_to @project, notice: notice
  end

  private

  def find_project
    @project = Project.friendly.find params[:project_id]
  end
end
