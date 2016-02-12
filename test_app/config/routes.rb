Rails.application.routes.draw do
  root 'trifle/static_pages#home'

  devise_for :users

  mount Trifle::Engine => "/trifle"

  if defined?(Trifle::ResqueAdmin) && defined?(Resque::Server)
    namespace :admin do
      constraints Trifle::ResqueAdmin do
        mount Resque::Server.new, at: 'queues'
      end
    end
  end

end
