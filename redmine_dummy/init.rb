Redmine::Plugin.register :redmine_dummy do
  name 'Redmine Dummy plugin'
  author 'Sahad'
  description 'This is a plugin for Redmine'
  version '0.0.1'
  url 'http://example.com/path/to/plugin'
  author_url 'http://example.com/about'
  # Add a menu item in the top navigation bar
  menu :top_menu, :redmine_dummy, { controller: 'dummy', action: 'index' }, caption: 'Dummy Demo'
end
