require 'sidekiq/web'

Rails.application.routes.draw do
  resources :apps

  root to: 'home#show'
  mount Sidekiq::Web => '/sidekiq'
end
