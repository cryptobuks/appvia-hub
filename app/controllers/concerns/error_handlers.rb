module ErrorHandlers
  extend ActiveSupport::Concern

  included do
    rescue_from ActionController::ParameterMissing, with: :unexpected_error
    rescue_from ResourceTypesService::UnknownResourceType, with: :unprocessable_entity_error
  end

  def unexpected_error(message = nil)
    flash_message = [
      'An unexpected error has occurred',
      message.present? ? "- #{message}" : nil
    ].compact.join(' ')

    flash[:error] = flash_message
    redirect_to root_path
  end

  def unprocessable_entity_error
    render file: Rails.root.join('public', '422.html'), layout: false, status: :unprocessable_entity
  end
end
