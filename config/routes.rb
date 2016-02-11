Trifle::Engine.routes.draw do
  root 'static_pages#home'

  get 'home' => 'static_pages#home'

  resources :iiif_manifests do
    resources :iiif_images, only: [:new, :create]
  end
  resources :iiif_images, only: [:show, :edit, :update, :destroy]
  resources :background_jobs, only: [:show]

  get '/iiif_manifests/:resource_id/background_jobs', to: 'background_jobs#index', as: :iiif_manifest_background_jobs
end
