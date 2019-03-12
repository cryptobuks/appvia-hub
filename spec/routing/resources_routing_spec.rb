require 'rails_helper'

RSpec.describe ResourcesController, type: :routing do
  describe 'routing' do
    it 'routes to #provision' do
      expect(post: '/apps/foo/resources/provision').to route_to('resources#provision', app_id: 'foo')
    end
  end
end
