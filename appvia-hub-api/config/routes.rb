Rails.application.routes.draw do
  scope format: false do
    root to: 'root#index'
  end
end
