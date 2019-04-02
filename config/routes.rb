require 'sidekiq/web'

Rails.application.routes.draw do
  resources :projects do
    resources :resources, only: [:destroy] do
      post :provision, on: :collection
    end
  end

  resources :users, only: %i[index]

  root to: 'home#show'
  mount Sidekiq::Web => '/sidekiq'
end
