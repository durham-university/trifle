Trifle::Engine.routes.draw do
  root 'static_pages#home'

  get 'home' => 'static_pages#home'

  resources :iiif_collections do
    resources :iiif_collections, only: [:new, :create]
    resources :iiif_manifests, only: [:new, :create]
  end

  post '/iiif_collections/:iiif_collection_id/iiif_manifests/deposit', to: 'iiif_manifests#create_and_deposit_images'
  resources :iiif_manifests, only: [:show, :edit, :update, :destroy, :index] do
    resources :iiif_images, only: [:new, :create]
    resources :iiif_structures, only: [:new, :create]
  end
  resources :iiif_images, only: [:show, :edit, :update, :destroy] do
    resources :iiif_annotation_lists, only: [:new, :create]
    resources :iiif_annotations, only: [:new, :create]
  end
  resources :iiif_annotation_lists, only: [:show, :edit, :update, :destroy] do
    resources :iiif_annotations, only: [:new, :create]
  end
  resources :iiif_annotations, only: [:show, :edit, :update, :destroy]
  
  resources :iiif_structures, only: [:show, :edit, :update, :destroy] do
    resources :iiif_structures, only: [:new, :create]
  end
  
  resources :background_jobs, only: [:show]
  
  get '/mirador', to: 'mirador#index', as: :mirador_index
  get '/mirador/:id', to: 'mirador#show', as: :mirador_manifest
  get '/mirador/:id/embed', to: 'mirador#show', as: :mirador_manifest_embed, defaults: { no_auto_load: 'true' }

  get '/iiif_collections/:resource_id/background_jobs', to: 'background_jobs#index', as: :iiif_collection_background_jobs
  get '/iiif_collections/:id/iiif', to: 'iiif_collections#show_iiif', as: :iiif_collection_iiif

  get '/iiif_manifests/:resource_id/background_jobs', to: 'background_jobs#index', as: :iiif_manifest_background_jobs
  get '/iiif_manifests/:id/iiif', to: 'iiif_manifests#show_iiif', as: :iiif_manifest_iiif
  post '/iiif_manifests/:id/deposit', to: 'iiif_manifests#deposit_images'
  
  get '/iiif_structures/:id/iiif',to: 'iiif_structures#show_iiif', as: :iiif_structure_iiif

  get '/iiif_images/:id/all_annotations', to: 'iiif_images#all_annotations', as: :iiif_image_all_annotations
  get '/iiif_images/:id/iiif', to: 'iiif_images#show_iiif', as: :iiif_image_iiif  
  get '/iiif_annotation_lists/:id/iiif', to: 'iiif_annotation_lists#show_iiif', as: :iiif_annotation_list_iiif
  get '/iiif_annotations/:id/iiif', to: 'iiif_annotations#show_iiif', as: :iiif_annotation_iiif
  
end
