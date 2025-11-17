require 'redmine'
require_relative 'lib/redmine_stats'

Redmine::Plugin.register :redmine_stats do
  name 'Redmine Stats Plugin'
  author 'AOUAITI Ahmed and Sahad Rushdi'
  description 'A plugin for Redmine to generate detailed statistics and reports about contributions and issues'
  version '1.0.0'
  url 'https://github.com/aouaiti/redmine_stats || https://github.com/SahadRushdi/redmine-plugins'

  # Lowered requirement to match your Redmine version
  requires_redmine version_or_higher: '5.1.0'

  # Add settings
  settings default: {
    'chart_theme': 'default',
    'default_period': 'month',
    'display_closed_issues': '1',
    'date_format': '%Y-%m-%d'
  }, partial: 'settings/stats_settings'

  # Add permissions
  project_module :stats do
    permission :view_stats, {
      stats: [:index, :show, :user_reports, :project_reports, :issue_reports],
    }, read: true

    permission :manage_stats, {
      stats_settings: [:edit, :update]
    }
  end

  # Add menu items
  menu :project_menu, :stats,
    { controller: 'stats', action: 'index' },
    caption: :label_stats,
    after: :activity,
    param: :project_id,
    if: Proc.new { |p| User.current.allowed_to?(:view_stats, p) }

  # Add admin menu
  menu :admin_menu, :stats_settings,
    { controller: 'settings', action: 'plugin', id: 'redmine_stats' },
    caption: :label_stats_settings
end

# 🔹 Disable asset precompile line for Redmine 5.x
# Rails.application.config.assets.precompile += %w(redmine_stats.css stats_charts.js)

# Apply patches
Rails.configuration.to_prepare do
  RedmineStats.apply_patches
end

