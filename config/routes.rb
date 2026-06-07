require "sidekiq/web"
require "sidekiq/cron/web"

Rails.application.routes.draw do
  use_doorkeeper
  # MFA routes
  resource :mfa, controller: "mfa", only: [ :new, :create ] do
    get :verify
    post :verify, to: "mfa#verify_code"
    delete :disable
  end

  mount Lookbook::Engine, at: "/design-system"

  # Uses basic auth - see config/initializers/sidekiq.rb
  mount Sidekiq::Web => "/sidekiq"

  # WebSocket endpoint for Action Cable
  mount ActionCable.server => "/cable"

  # AI chats
  resources :chats do
    resources :messages, only: :create

    member do
      post :retry
    end
  end

  resources :family_exports, only: %i[new create index destroy] do
    member do
      get :download
    end
  end

  get "changelog", to: "pages#changelog"
  get "feedback", to: "pages#feedback"
  get "sankey-demo", to: "pages#sankey_demo"
  get "tabs-demo", to: "pages#tabs_demo"

  resource :current_session, only: %i[update]

  resource :registration, only: %i[new create]

  # Subscription Manager routes
  get "/recurring", to: "recurring#index", as: :recurring

  resources :subscription_plans do
    collection do
      get :check_duplicate
    end
    member do
      patch :pause
      patch :resume
      patch :cancel
      patch :undo_cancellation
    end
    resources :subscription_renewals, only: %i[index new create show]
  end

  # Services management
  resources :services, except: :show do
    collection do
      post :seed_popular
    end
  end

  # Legacy subscription routes (for backward compatibility)
  get "/subscriptions", to: redirect("/subscription_plans")
  get "/subscriptions/new", to: redirect("/subscription_plans/new")
  resources :sessions, only: %i[new create destroy]
  match "/auth/:provider/callback", to: "sessions#openid_connect", via: %i[get post]
  match "/auth/failure", to: "sessions#failure", via: %i[get post]
  resource :oidc_account, only: [] do
    get :link, on: :collection
    post :create_link, on: :collection
    get :new_user, on: :collection
    post :create_user, on: :collection
  end
  resource :password_reset, only: %i[new create edit update]
  resource :password, only: %i[edit update]
  resource :email_confirmation, only: :new

  resources :users, only: %i[update destroy] do
    delete :reset, on: :member
    delete :reset_with_sample_data, on: :member
    patch :rule_prompt_settings, on: :member
    get :resend_confirmation_email, on: :member
  end

  resource :onboarding, only: :show do
    collection do
      get :preferences
      get :goals
      get :trial
    end
  end

  namespace :settings do
    resource :profile, only: [ :show, :destroy ]
    resource :preferences, only: :show
    resource :password, only: [ :edit, :update ]
    resource :hosting, only: %i[show update] do
      delete :clear_cache, on: :collection
    end
    resource :billing, only: :show
    resource :security, only: :show
    resource :api_key, only: [ :show, :new, :create, :destroy ]
    resource :ai_prompts, only: :show
    resource :llm_usage, only: :show
    resource :guides, only: :show
    resource :bank_sync, only: :show, controller: "bank_sync"
    resource :providers, only: %i[show update] do
      post :test_connection, on: :collection
    end
    resources :provider_directories, path: "providers-directory", except: :show do
      patch :restore, on: :member
    end
    resource :sync_monitor, only: :show, controller: "sync_monitors" do
      post :sync_target, on: :member
      post :retry_sync, on: :member
      post :retry_all_failed, on: :collection
      post :dismiss_sync, on: :member
      post :dismiss_all_stale, on: :collection
      post :sync_all, on: :collection
    end
  end

  resource :subscription, only: %i[new show create] do
    collection do
      get :upgrade
      get :success
    end
  end

  resources :tags, except: :show do
    resources :deletions, only: %i[new create], module: :tag
    delete :destroy_all, on: :collection
  end

  namespace :category do
    resource :dropdown, only: :show
  end

  resources :categories, except: :show do
    resources :deletions, only: %i[new create], module: :category

    post :bootstrap, on: :collection
    delete :destroy_all, on: :collection
  end

  resources :budgets, only: %i[index show edit update], param: :month_year do
    get :picker, on: :collection

    resources :budget_categories, only: %i[index show update]
  end

  resources :reports, only: %i[index] do
    get :export_transactions, on: :collection
    get :google_sheets_instructions, on: :collection
  end

  resources :family_merchants, only: %i[index new create edit update destroy]

  resources :transfers, only: %i[new create destroy show update] do
    post :mark_as_recurring, on: :member
  end

  resources :imports, only: %i[index new show create destroy] do
    member do
      post :publish
      put :revert
      put :apply_template
    end

    resource :upload, only: %i[show update], module: :import
    resource :configuration, only: %i[show update], module: :import
    resource :clean, only: :show, module: :import
    resource :confirm, only: :show, module: :import

    resources :rows, only: %i[show update], module: :import
    resources :mappings, only: :update, module: :import
  end

  resources :holdings, only: %i[index new show destroy]
  resources :trades, only: %i[show new create update destroy]
  resources :valuations, only: %i[show new create update destroy] do
    post :confirm_create, on: :collection
    post :confirm_update, on: :member
  end

  namespace :transactions do
    resource :bulk_deletion, only: :create
    resource :bulk_update, only: %i[new create]
  end

  resources :transactions, only: %i[index new create show update destroy] do
    resource :split, only: %i[new create edit update destroy]
    resource :transfer_match, only: %i[new create]
    resource :category, only: :update, controller: :transaction_categories

    member do
      post :merge_duplicate
      post :dismiss_duplicate
    end

    collection do
      delete :clear_filter
    end
  end

  resources :precious_metal_transactions, only: %i[new create]

  resources :recurring_transactions, only: %i[index destroy] do
    collection do
      get :identify
      post :identify
      post :cleanup
    end

    member do
      post :toggle_status
      post :create_subscription
      post :restore
      post :confirm
      post :mark_transfer
    end
  end

  resources :accountable_sparklines, only: :show, param: :accountable_type

  direct :entry do |entry, options|
    if entry.new_record?
      route_for entry.entryable_name.pluralize, options
    else
      route_for entry.entryable_name, entry, options
    end
  end

  # Entry receipts - attachment management for transaction documentation (stored in R2)
  resources :entries, only: [] do
    resource :receipt, only: :destroy, controller: "entry_receipts"
  end

  resources :rules, except: :show do
    member do
      get :confirm
      post :apply
    end

    collection do
      delete :destroy_all
      get :confirm_all
      post :apply_all
      post :clear_ai_cache
    end
  end

  resources :accounts, only: %i[index new show destroy], shallow: true do
    member do
      post :sync
      get :sparkline
      patch :toggle_active
      get :value
      get :select_provider
      get :confirm_unlink
      delete :unlink
    end

    collection do
      post :sync_all
    end
  end

  # Convenience routes for polymorphic paths
  # Example: account_path(Account.new(accountable: Depository.new)) => /depositories/123
  direct :edit_account do |model, options|
    route_for "edit_#{model.accountable_name}", model, options
  end

  resources :depositories, only: %i[new create edit update]
  resources :investments, only: %i[new create edit update]
  resources :properties, only: %i[new create edit update] do
    member do
      get :balances
      patch :update_balances

      get :address
      patch :update_address
    end
  end
  resources :vehicles, only: %i[new create edit update]
  resources :credit_cards, only: %i[new create edit update]
  resources :pay_laters, only: %i[new create edit update show] do
    member do
      # Purchase flow
      get :new_purchase
      post :create_purchase
      get :preview_installments

      # Payment flow
      get :new_payment
      post :process_payment

      # Schedule and early settlement
      get :schedule
      get :early_settlement
      post :process_early_settlement
    end
  end
  resources :loans, only: %i[new create edit update] do
    collection do
      get :schedule_preview
    end
    member do
      get :schedule_preview
      get :new_borrowing
      post :create_borrowing
      get :new_payment
      post :create_payment
      post :post_installment
      get :new_extra_payment
      post :create_extra_payment
      post :record_backdated_payment
    end
  end
  resources :personal_lendings, only: %i[new create edit update] do
    collection do
      get :new_global_lending
      post :create_global_lending
      get :new_global_payment
      post :create_global_payment
    end
    member do
      get :new_lending
      post :create_lending
      get :new_payment
      post :create_payment
    end
  end
  resources :cryptos, only: %i[new create edit update]
  resources :precious_metals, only: %i[new create edit update]
  resources :other_assets, only: %i[new create edit update]
  resources :other_liabilities, only: %i[new create edit update]

  resources :securities, only: :index

  resources :invite_codes, only: %i[index create destroy]

  resources :invitations, only: [ :new, :create, :destroy ] do
    get :accept, on: :member
  end

  # API routes
  namespace :api do
    namespace :v1 do
      # Authentication endpoints
      post "auth/signup", to: "auth#signup"
      post "auth/login", to: "auth#login"
      post "auth/refresh", to: "auth#refresh"

      # Production API endpoints
      resources :accounts, only: [ :index ]
      resources :categories, only: [ :index, :show ]
      resources :transactions, only: [ :index, :show, :create, :update, :destroy ]
      # PayLater endpoints (manual-only)
      namespace :debt do
        post "paylater", to: "pay_later#create"
        post "paylater/expense", to: "pay_later#expense"
        post "paylater/installment/pay", to: "pay_later#pay_installment"
        post "loans/plan/preview", to: "loans#preview"
        post "loans/installment/post", to: "loans#post_installment"
        post "loans/plan/regenerate", to: "loans#regenerate"
      end
      resource :usage, only: [ :show ], controller: "usage"
      post :sync, to: "sync#create"

      resources :chats, only: [ :index, :show, :create, :update, :destroy ] do
        resources :messages, only: [ :create ] do
          post :retry, on: :collection
        end
      end

      # Test routes for API controller testing (only available in test environment)
      if Rails.env.test?
        get "test", to: "test#index"
        get "test_not_found", to: "test#not_found"
        get "test_family_access", to: "test#family_access"
        get "test_scope_required", to: "test#scope_required"
        get "test_multiple_scopes_required", to: "test#multiple_scopes_required"
      end
    end
  end



  resources :currencies, only: %i[show]

  resources :impersonation_sessions, only: [ :create ] do
    post :join, on: :collection
    delete :leave, on: :collection

    member do
      put :approve
      put :reject
      put :complete
    end
  end

  resources :plaid_items, only: %i[new edit create destroy] do
    collection do
      get :select_existing_account
      post :link_existing_account
    end

    member do
      post :sync
    end
  end

  resources :simplefin_items, only: %i[index new create show edit update destroy] do
    collection do
      get :select_existing_account
      post :link_existing_account
    end

    member do
      post :sync
      post :balances
      get :errors
      get :setup_accounts
      post :complete_account_setup
    end
  end

  # PostHog Proxy
  match "/ingest/*path", to: "posthog_proxy#proxy", via: :all

  resources :lunchflow_items, only: %i[index new create show edit update destroy] do
    collection do
      get :preload_accounts
      get :select_accounts
      post :link_accounts
      get :select_existing_account
      post :link_existing_account
    end

    member do
      post :sync
    end
  end

  namespace :webhooks do
    post "plaid"
    post "plaid_eu"
    post "stripe"
  end

  get "redis-configuration-error", to: "pages#redis_configuration_error"

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/*
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest

  get "imports/:import_id/upload/sample_csv", to: "import/uploads#sample_csv", as: :import_upload_sample_csv

  # Keep Permoney's meaningful redirects and custom demo route
  get "privacy", to: redirect("https://maybefinance.com/privacy")
  get "terms", to: redirect("https://maybefinance.com/tos")
  get "carousel-demo", to: "pages#carousel_demo"
  get "styleguide", to: "styleguide#index"

  # Defines the root path route ("/")
  root "pages#dashboard"
end
