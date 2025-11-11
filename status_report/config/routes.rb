# Plugin's routes
# See: http://guides.rubyonrails.org/routing.html
# The routes file for the StatusReport plugin
match 'status_report', to: 'reports#index', via: [:get], as: 'status_report'
