module Admin
  class IntegrationsController < Admin::BaseController
    before_action :find_integration, only: %i[edit update]

    # GET /admin/integrations
    # rubocop:disable Metrics/MethodLength
    def index
      integrations_by_provider = Integration.all.group_by(&:provider_id)

      @unmask = params.key? 'unmask'

      @groups = [
        {
          name: 'Code Repositories',
          resource_type: 'CodeRepo',
          providers: [
            {
              definition: PROVIDERS_REGISTRY.get('git_hub'),
              integrations: Array(integrations_by_provider['git_hub'])
            }
          ]
        },
        {
          name: 'Docker Repositories',
          resource_type: 'DockerRepo',
          providers: [
            {
              definition: PROVIDERS_REGISTRY.get('quay'),
              integrations: Array(integrations_by_provider['quay'])
            }
          ]
        },
        {
          name: 'Kubernetes Namespaces',
          resource_type: 'KubeNamespace',
          providers: [
            {
              definition: PROVIDERS_REGISTRY.get('kubernetes'),
              integrations: Array(integrations_by_provider['kubernetes'])
            }
          ]
        }
      ]
    end
    # rubocop:enable Metrics/MethodLength

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
        redirect_to admin_integrations_path, notice: 'New integration was successfully created.'
      else
        render :new
      end
    end

    # PATCH/PUT /admin/integrations/:id
    def update
      if @integration.update integration_params
        redirect_to admin_integrations_path, notice: 'Integration was successfully updated.'
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
  end
end
