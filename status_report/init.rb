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
end
