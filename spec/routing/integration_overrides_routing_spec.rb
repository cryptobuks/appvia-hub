require 'rails_helper'

RSpec.describe IntegrationOverridesController, type: :routing do
  describe 'routing' do
    it 'routes to #show' do
      expect(get: '/spaces/foo/integration_overrides').to route_to('integration_overrides#show', project_id: 'foo')
    end

    it 'routes to #update' do
      expect(put: '/spaces/foo/integration_overrides').to route_to('integration_overrides#update', project_id: 'foo')
    end
  end
end
