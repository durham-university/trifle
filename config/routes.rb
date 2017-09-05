Trifle::Engine.routes.draw do
  # The routes should, as much as is possible, follow IIIF recommended URI patterns
  # http://iiif.io/api/presentation/2.1/#a-summary-of-recommended-uri-patterns
  # Note that additional route helpers are created in lib/trifle/engine.rb to
  # make IIIF routes compatible with DurhamRails conventions.
  
  root 'static_pages#home'

  get 'home' => 'static_pages#home'

  resources :iiif_collections, path: 'collection' do
    resources :iiif_collections, only: [:new, :create], path: 'collection'
    resources :iiif_manifests, only: [:new, :create], path: 'manifest'
  end
  
  get '/collection/:resource_id/background_jobs', to: 'background_jobs#index', as: :iiif_collection_background_jobs
  post '/collection/:iiif_collection_id/manifest/deposit', to: 'iiif_manifests#create_and_deposit_images'
  
  resources :iiif_manifests, only: [:show, :edit, :update, :destroy, :index], path: 'manifest' do
    resources :iiif_images, only: [:new, :create, :show, :edit, :update, :destroy], path: 'canvas' do
      resources :iiif_annotation_lists, only: [:new, :create], path: 'list'
      resources :iiif_annotations, only: [:new, :create], path: 'annotation'
    end
    resources :iiif_annotation_lists, only: [:show, :edit, :update, :destroy], path: 'list' do
      resources :iiif_annotations, only: [:new, :create], path: 'annotation'
    end
    resources :iiif_annotations, only: [:show, :edit, :update, :destroy], path: 'annotation'
    
    resources :iiif_ranges, only: [:new, :create, :show, :edit, :update, :destroy], path: 'range' do
      resources :iiif_ranges, only: [:new, :create], path: 'range'
    end
  end

  get 'image', to: 'iiif_images#index', as: :iiif_images # This is only for indexing images from a particular source
  
  get '/manifest/:id/manifest', to: 'iiif_manifests#show'
  get '/manifest/:resource_id/background_jobs', to: 'background_jobs#index', as: :iiif_manifest_background_jobs
  post '/manifest/:id/deposit', to: 'iiif_manifests#deposit_images'
  post '/manifest/:id/refresh_from_source', to: 'iiif_manifests#refresh_from_source', as: :iiif_manifest_refresh_from_source
  post '/manifest/:id/publish', to: 'iiif_manifests#publish', as: :iiif_manifest_publish
  get '/manifest/:iiif_manifest_id/canvas/:id/all_annotations', to: 'iiif_images#all_annotations', as: :iiif_manifest_iiif_image_all_annotations
  post '/manifest/:iiif_manifest_id/canvas/:id/refresh_from_source', to: 'iiif_images#refresh_from_source', as: :iiif_manifest_iiif_image_refresh_from_source
  post '/manifest/:id/update_ranges', to: 'iiif_manifests#update_ranges', as: :iiif_manifest_update_ranges
  post '/manifest/:id/link_millennium', to: 'iiif_manifests#link_millennium', as: :iiif_manifest_link_millennium
  post '/canvas/:id/link_millennium', to: 'iiif_images#link_millennium', as: :iiif_image_link_millennium
  get '/canvas/:resource_id/background_jobs', to: 'background_jobs#index', as: :iiif_image_background_jobs
  
  post '/manifest/:id/select', to: 'iiif_manifests#select_resource', as: :select_iiif_manifest
  post '/manifest/:id/deselect', to: 'iiif_manifests#deselect_resource', as: :deselect_iiif_manifest
  post '/manifest/deselect_all', to: 'iiif_manifests#deselect_all_resources'
  post '/manifest/:id/deselect_all', to: 'iiif_manifests#deselect_all_resources', as: :deselect_all_iiif_manifest
  post '/collection/:id/select', to: 'iiif_collections#select_resource', as: :select_iiif_collection
  post '/collection/:id/deselect', to: 'iiif_collections#deselect_resource', as: :deselect_iiif_collection
  post '/collection/deselect_all', to: 'iiif_collections#deselect_all_resources'
  post '/collection/:id/deselect_all', to: 'iiif_collections#deselect_all_resources', as: :deselect_all_iiif_collection
  post '/collection/:id/move_into', to: 'iiif_collections#move_selection_into', as: :move_into_iiif_collection
  post '/collection/:id/publish', to: 'iiif_collections#publish', as: :iiif_collection_publish
  post '/collection/:id/link_millennium', to: 'iiif_collections#link_millennium', as: :iiif_collection_link_millennium
  
  
  scope 'iiif' do
    get 'collection', to: 'iiif_collections#index_iiif', as: :iiif_collection_index_iiif
    get 'collection/:id', to: 'iiif_collections#show_iiif', as: :iiif_collection_iiif
    get 'manifest/:id/manifest', to: 'iiif_manifests#show_iiif', as: :iiif_manifest_iiif
    get 'manifest/:id', to: 'iiif_manifests#show_iiif'
    get 'manifest/:id/sequence/:sequence_name', to: 'iiif_manifests#show_sequence_iiif', as: :iiif_manifest_sequence_iiif
    get 'manifest/:iiif_manifest_id/canvas/:id', to: 'iiif_images#show_iiif', as: :iiif_manifest_iiif_image_iiif    
    get 'manifest/:iiif_manifest_id/annotation/canvas_:id', to: 'iiif_images#show_annotation_iiif', as: :iiif_manifest_iiif_image_annotation_iiif
    get 'manifest/:iiif_manifest_id/list/:id', to: 'iiif_annotation_lists#show_iiif', as: :iiif_manifest_iiif_annotation_list_iiif    
    get 'manifest/:iiif_manifest_id/annotation/:id', to: 'iiif_annotations#show_iiif', as: :iiif_manifest_iiif_annotation_iiif    
    get 'manifest/:iiif_manifest_id/range/:id',to: 'iiif_ranges#show_iiif', as: :iiif_manifest_iiif_range_iiif
  end
  get '/iiif/manifest/:iiif_manifest_id/canvas/:id/all_annotations', to: 'iiif_images#all_annotations', as: :iiif_manifest_iiif_image_all_annotations_iiif
  
  resources :background_jobs, only: [:show]
  post '/background_jobs/:id/rerun_job', to: 'background_jobs#rerun_job'
  
  get '/exports', to: 'exports#show', as: :exports
  post '/exports', to: 'exports#export_images'
  
#  get '/mirador', to: 'mirador#index', as: :mirador_index
  get '/mirador/:id', to: 'mirador#show', as: :mirador_manifest
  get '/mirador/:id/embed', to: 'mirador#show', as: :mirador_manifest_embed, defaults: { no_auto_load: 'true' }
    
  resources :background_job_containers, as: :durham_rails_background_job_containers
  get '/background_job_containers/:resource_id/background_jobs', to: 'background_jobs#index', as: :durham_rails_background_job_container_background_jobs
  
end
