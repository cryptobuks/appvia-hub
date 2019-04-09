require 'rails_helper'

RSpec.describe ResourcesController, type: :routing do
  describe 'routing' do
    it 'routes to #destroy' do
      expect(delete: '/spaces/foo/resources/1').to route_to('resources#destroy', project_id: 'foo', id: '1')
    end

    it 'routes to #provision' do
      expect(post: '/spaces/foo/resources/provision').to route_to('resources#provision', project_id: 'foo')
    end
  end
end
