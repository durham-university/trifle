Trifle::Engine.routes.draw do
  root 'static_pages#home'

  get 'home' => 'static_pages#home'

  resources :iiif_manifests do
    resources :iiif_images, only: [:new, :create]
  end
  resources :iiif_images, only: [:show, :edit, :update, :destroy]

end
