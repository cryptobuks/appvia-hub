class AppsController < ApplicationController
  before_action :find_app, only: %i[show edit update destroy]

  # GET /apps
  def index
    @apps = App.order(:name)
  end

  # GET /apps/:id
  def show
    @activity = ActivityService.new.for_app @app
  end

  # GET /apps/new
  def new
    @app = App.new
  end

  # GET /apps/:id/edit
  def edit; end

  # POST /apps
  def create
    @app = App.new app_params

    if @app.save
      AppBootstrapService.new(@app).bootstrap

      redirect_to @app, notice: 'App was successfully created.'
    else
      render :new
    end
  end

  # PATCH/PUT /apps/:id
  def update
    if @app.update app_params
      redirect_to @app, notice: 'App was successfully updated.'
    else
      render :edit
    end
  end

  # DELETE /apps/:id
  def destroy
    @app.destroy
    redirect_to apps_url, notice: 'App was successfully deleted.'
  end

  private

  def find_app
    @app = App.friendly.find params[:id]
  end

  def app_params
    params.require(:app).permit(:name, :slug, :description)
  end
end
