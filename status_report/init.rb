Redmine::Plugin.register :status_report do
  name 'Status Report plugin'
  author 'Sahad'
  description 'Generates a PDF report of all active project statuses and issues.'
  version '0.0.1'
  url 'http://example.com/path/to/plugin'
  author_url 'http://example.com/about'

  menu :top_menu, :status_report, { controller: 'reports', action: 'index' }, 
       caption: 'Get Current Status', 
       after: :my_page # Position the link after 'My page'
  
  # Define the project module
  project_module :status_report_module do
    permission :view_recent_issues_widget, {}, :public => true
  end
end

# Include helper for My Page blocks
Rails.application.config.to_prepare do
  MyHelper.send(:include, StatusReportMyHelper)
end

# Load hooks
require_relative 'lib/status_report/hooks'
