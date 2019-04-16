class ResourcesController < ApplicationController
  before_action :find_project

  before_action :find_resource_type, only: %i[new create]
  before_action :find_integrations, only: %i[new create]

  before_action :find_resource, only: [:destroy]

  def new
    @resource = @project.resources.new type: @resource_type[:class]
  end

  def create
    @resource = @project.resources.new resource_params

    if @resource.save
      ResourceProvisioningService.new.request_create @resource

      redirect_to @project, notice: 'Resource has been requested.'
    else
      render :new
    end
  end

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

  def find_resource_type
    @resource_type = ResourceTypesService.get params.require(:type)
  end

  def find_integrations
    @integrations = ResourceTypesService.integrations_for @resource_type[:id]

    if @integrations.empty? # rubocop:disable Style/GuardClause
      flash[:warning] = 'No integrations are available for the resource type - ask a hub admin to configure an appropriate integration'
      redirect_back fallback_location: root_path, allow_other_host: false
    end
  end

  def find_resource
    @resource = @project.resources.find params[:id]
  end

  def resource_params
    params.require(:resource).permit(:type, :integration_id, :name)
  end
end
