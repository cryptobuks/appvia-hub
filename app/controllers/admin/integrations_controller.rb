module Admin
  class IntegrationsController < Admin::BaseController
    before_action :find_integration, only: %i[edit update]

    # GET /admin/integrations
    def index
      integrations_by_provider = Integration.all.group_by(&:provider_id)

      @group_to_expand = params[:expand]
      @unmask = params.key? 'unmask'

      @groups = ResourceTypesService.all.map do |rt|
        providers = rt[:providers].map do |provider_id|
          {
            definition: PROVIDERS_REGISTRY.get(provider_id),
            integrations: Array(integrations_by_provider[provider_id])
          }
        end

        rt.merge providers: providers
      end
    end

    # GET /admin/integrations/new
    def new
      provider_id = params.require(:provider_id)

      unprocessable_entity_error && return unless Integration.provider_ids.key?(provider_id)

      @integration = Integration.new provider_id: provider_id
    end

    # GET /admin/integrations/:id/edit
    def edit; end

    # POST /admin/integrations
    def create
      @integration = Integration.new integration_params

      if @integration.save
        path = admin_integrations_path_with_selected @integration
        redirect_to path, notice: 'New integration was successfully created.'
      else
        render :new
      end
    end

    # PATCH/PUT /admin/integrations/:id
    def update
      if @integration.update integration_params
        path = admin_integrations_path_with_selected @integration
        redirect_to path, notice: 'Integration was successfully updated.'
      else
        render :edit
      end
    end

    private

    def find_integration
      @integration = Integration.find params[:id]
    end

    def integration_params
      params.require(:integration).permit(:provider_id, :name, config: {})
    end

    def admin_integrations_path_with_selected(integration)
      resource_type = ResourceTypesService.for_provider integration.provider_id

      admin_integrations_path(
        expand: resource_type[:id],
        anchor: integration.id
      )
    end
  end
end
