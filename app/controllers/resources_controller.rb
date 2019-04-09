class ResourcesController < ApplicationController
  before_action :find_project

  before_action :find_resource, only: [:destroy]

  def destroy
    ResourceProvisioningService.new.request_delete @resource
    redirect_to @project, notice: 'Deletion of resource has been requested.'
  end

  def provision
    result = ProjectResourcesService.new(@project).bootstrap

    notice = ('A new set of resources have been requested for this space' if result)

    redirect_to @project, notice: notice
  end

  private

  def find_project
    @project = Project.friendly.find params[:project_id]
  end

  def find_resource
    @resource = @project.resources.find params[:id]
  end
end
