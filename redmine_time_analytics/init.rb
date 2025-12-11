Redmine::Plugin.register :redmine_time_analytics do
  name 'Redmine Time Analytics Plugin'
  author 'Sahad'
  description 'Comprehensive time tracking analytics and reporting for Redmine'
  version '1.0.0'
  url 'http://example.com/path/to/plugin'
  author_url 'http://example.com/about'

  # Add to top menu
  menu :top_menu, :time_analytics, { controller: 'time_analytics', action: 'index' }, 
       caption: :label_time_analytics, after: :my_page

  # Add permissions
  project_module :time_analytics do
    permission :view_time_analytics, { time_analytics: [:index, :individual_dashboard] }
  end
end