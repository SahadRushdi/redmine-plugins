RedmineApp::Application.routes.draw do
  get 'time_analytics', to: 'time_analytics#index'
  get 'time_analytics/individual_dashboard', to: 'time_analytics#individual_dashboard'
  get 'time_analytics/team_dashboard', to: 'time_analytics#team_dashboard'
  get 'time_analytics/custom_dashboard', to: 'time_analytics#custom_dashboard'
  post 'time_analytics/export_csv', to: 'time_analytics#export_csv'
end