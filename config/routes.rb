Trifle::Engine.routes.draw do
  root 'static_pages#home'

  get 'home' => 'static_pages#home'

  post '/iiif_manifests/deposit', to: 'iiif_manifests#create_and_deposit_images'
  resources :iiif_manifests do
    resources :iiif_images, only: [:new, :create]
  end
  resources :iiif_images, only: [:show, :edit, :update, :destroy]
  resources :background_jobs, only: [:show]
  
  get '/mirador', to: 'mirador#index', as: :mirador_index
  get '/mirador/:id', to: 'mirador#show', as: :mirador_manifest
  get '/mirador/:id/embed', to: 'mirador#show', as: :mirador_manifest_embed, defaults: { no_auto_load: 'true' }

  get '/iiif_manifests/:resource_id/background_jobs', to: 'background_jobs#index', as: :iiif_manifest_background_jobs
  get '/iiif_manifests/:id/manifest', to: 'iiif_manifests#manifest', as: :iiif_manifest_manifest
  post '/iiif_manifests/:id/deposit', to: 'iiif_manifests#deposit_images'
  
end
