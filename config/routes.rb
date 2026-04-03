Rails.application.routes.draw do
  root to: redirect("/up")
  devise_for :users, skip: :all

  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      namespace :auth do
        get :csrf, to: "csrf_tokens#show"
      end

      devise_scope :user do
        post "auth/sign_up", to: "auth/registrations#create"
        post "auth/sign_in", to: "auth/sessions#create"
        delete "auth/sign_out", to: "auth/sessions#destroy"
      end

      resource :me, controller: :me, only: %i[show update]
      resources :accounts, except: %i[new edit]
      resources :credit_cards, except: %i[new edit] do
        resources :card_holders, except: %i[new edit], shallow: true
      end
      resources :categories, except: %i[new edit]
      resources :category_suggestion_rules, except: %i[new edit]
      resources :category_suggestions, only: %i[create]
      resources :tags, except: %i[new edit]
      resources :statements, only: %i[index show]
      resources :transactions, except: %i[new edit]
      resources :imports, only: %i[index show create update destroy] do
        post :confirm, on: :member
      end
      resources :import_items, only: %i[update]
      resources :budgets, except: %i[new edit]
      resources :recurring_rules, except: %i[new edit]

      namespace :reports do
        get :overview
        get :monthly_flow
        get :category_breakdown
        get :budget_status
        get :merchant_ranking
      end

      unless Rails.env.production?
        namespace :dev do
          get :materialize_recurring_rules, to: "tools#materialize_recurring_rules"
        end
      end
    end
  end
end
