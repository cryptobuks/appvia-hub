class ProjectsController < ApplicationController
  before_action :find_project, only: %i[show edit update destroy]

  # GET /projects
  def index
    @projects = Project.order(:name)
  end

  # GET /projects/:id
  def show
    @activity = ActivityService.new.for_project @project
  end

  # GET /projects/new
  def new
    @project = Project.new
  end

  # GET /projects/:id/edit
  def edit; end

  # POST /projects
  def create
    @project = Project.new project_params

    if @project.save
      redirect_to @project, notice: 'Project was successfully created.'
    else
      render :new
    end
  end

  # PATCH/PUT /projects/:id
  def update
    if @project.update project_params
      redirect_to @project, notice: 'Project was successfully updated.'
    else
      render :edit
    end
  end

  # DELETE /projects/:id
  def destroy
    @project.destroy
    redirect_to projects_url, notice: 'Project was successfully deleted.'
  end

  private

  def find_project
    @project = Project.friendly.find params[:id]
  end

  def project_params
    params.require(:project).permit(:name, :slug, :description)
  end
end
