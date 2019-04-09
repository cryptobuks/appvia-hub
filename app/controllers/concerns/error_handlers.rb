module ErrorHandlers
  extend ActiveSupport::Concern

  def unprocessable_entity_error
    render file: Rails.root.join('public', '422.html'), layout: false, status: :unprocessable_entity
  end
end
