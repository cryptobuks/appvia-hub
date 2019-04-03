class ResourcesController < ApplicationController
  before_action :find_project

  before_action :find_resource, only: [:destroy]

  # DELETE /projects/:project_id/resources/:id
  def destroy
    ResourceProvisioningService.new.request_delete @resource
    redirect_to @project, notice: 'Deletion of resource has been requested.'
  end

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

  def find_resource
    @resource = @project.resources.find params[:id]
  end
end
