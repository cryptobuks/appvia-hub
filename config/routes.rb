require 'sidekiq/web'

Rails.application.routes.draw do
  resources :apps do
    resources :resources, only: [] do
      post :provision, on: :collection
    end
  end

  root to: 'home#show'
  mount Sidekiq::Web => '/sidekiq'
end
