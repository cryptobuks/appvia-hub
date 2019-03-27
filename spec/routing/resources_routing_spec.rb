require 'rails_helper'

RSpec.describe ResourcesController, type: :routing do
  describe 'routing' do
    it 'routes to #provision' do
      expect(post: '/projects/foo/resources/provision').to route_to('resources#provision', project_id: 'foo')
    end
  end
end
