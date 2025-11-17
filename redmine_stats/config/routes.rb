# Plugin's routes
# See: http://guides.rubyonrails.org/routing.html

Rails.application.routes.draw do
  # Main stats routes within projects
  resources :projects do
    resources :stats, only: [:index] do
      collection do
        get 'user_reports'
        get 'project_reports'
        get 'issue_reports'
      end
    end
  end
  
  # Admin area routes
  get 'stats/global_overview', as: 'global_stats_overview'
end 