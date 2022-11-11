Rails.application.routes.draw do
  concern :collaboratable do
    resources :collaborations, only: [:create, :destroy, :index, :show]
  end

  concern :activities do
    resources :activities, only: [:index]
  end

  get 'edam/terms' => 'edam#terms'
  get 'edam/topics' => 'edam#topics'
  get 'edam/operations' => 'edam#operations'

  #get 'static/home'
  get 'about' => 'about#tess', as: 'about'
  get 'about/registering' => 'about#registering', as: 'registering_resources'
  get 'about/developers' => 'about#developers', as: 'developers'
  get 'about/us' => 'about#us', as: 'us'

  get 'privacy' => 'static#privacy', as: 'privacy'

  post 'materials/check_exists' => 'materials#check_exists'
  post 'events/check_exists' => 'events#check_exists'
  post 'content_providers/check_exists' => 'content_providers#check_exists'
  post 'sources/check_exists' => 'sources#check_exists'

  #devise_for :users
  # Use custom invitations and registrations controllers that subclasses devise's
  # Devise will try to connect to the DB at initialization, which we don't want
  # to happen when precompiling assets in the docker build script.
  unless Rake.try(:application)&.top_level_tasks&.include? 'assets:precompile'
    devise_for :users, :controllers => {
      :registrations => 'tess_devise/registrations',
      :invitations => 'tess_devise/invitations',
      :omniauth_callbacks => 'callbacks'
    }
  end
  #Redirect to users index page after devise user account update
  # as :user do
  #   get 'users', :to => 'users#index', :as => :user_root
  # end

  patch 'users/:id/change_token' => 'users#change_token', as: 'change_token'

  mount RailsAdmin::Engine => '/admin', as: 'rails_admin'

  root 'static#home'

  get 'static/home'

  resources :users do
    resource :ban, only: [:create, :new, :destroy]
  end

  resources :trainers, only: [:show, :index]

  resources :nodes, concerns: :activities

  resources :events, concerns: :activities do
    collection do
      get 'count'
    end
    member do
      get 'redirect'
      post 'add_term'
      post 'add_data'
      post 'reject_term'
      post 'reject_data'
      get 'report'
      patch 'report', to: 'events#update_report'
      get 'clone', to: 'events#clone'
    end
  end

  resources :collections, concerns: [:collaboratable, :activities]

  resources :workflows, concerns: [:collaboratable, :activities] do
    member do
      get 'fork'
      get 'embed'
    end
  end

  resources :content_providers, concerns: :activities do
    member do
      get 'import'
      get 'scraper_results'
      post 'import', to: 'content_providers#scrape'
      post 'bulk_create'
    end
    resources :sources, except: [:index]
  end

  resources :sources, except: [:new, :create], concerns: :activities do
    member do
      get :test_results
      post :test
    end
  end

  resources :materials, concerns: :activities do
    member do
      post :reject_term
      post :reject_data
      post :add_term
      post :add_data
    end
    collection do
      get 'count'
    end
  end

  get 'elearning_materials' => 'materials#index', defaults: { 'resource_type' => 'e-learning' }

  get 'invitees' => 'users#invitees'

  resources :subscriptions, only: [:show, :index, :create, :destroy] do
    member do
      get 'unsubscribe'
    end
  end

  get 'stars' => 'stars#index'
  post 'stars' => 'stars#create'
  delete 'stars' => 'stars#destroy'

  post 'materials/:id/update_collections' => 'materials#update_collections'
  post 'events/:id/update_collections' => 'events#update_collections'

  get 'search' => 'search#index'
  get 'test_url' => 'application#test_url'
  get 'job_status' => 'application#job_status'

  # error pages
  %w( 404 422 500 503 ).each do |code|
    get code, :to => "application#handle_error", :status_code => code
  end

  get 'curate/topic_suggestions' => 'curator#topic_suggestions'
  get 'curate/users' => 'curator#users'
  get 'curate' => 'curator#index'

  require 'sidekiq/web'
  authenticate :user, lambda { |u| u.is_admin? } do
    mount Sidekiq::Web, at: '/sidekiq'
  end

  get 'resolve/:prefix:type:id' => 'resolution#resolve', constraints: { prefix: /(.+\:)?/, type: /[a-zA-Z]/, id: /\d+/ }

  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".

  # You can have the root of your site routed with "root"
  # root 'welcome#index'

  # Example of regular route:
  #   get 'products/:id' => 'catalog#view'

  # Example of named route that can be invoked with purchase_url(id: product.id)
  #   get 'products/:id/purchase' => 'catalog#purchase', as: :purchase

  # Example resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Example resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Example resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Example resource route with more complex sub-resources:
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', on: :collection
  #     end
  #   end

  # Example resource route with concerns:
  #   concern :toggleable do
  #     post 'toggle'
  #   end
  #   resources :posts, concerns: :toggleable
  #   resources :photos, concerns: :toggleable

  # Example resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end
end
