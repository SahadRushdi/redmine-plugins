module RedmineStats
  class << self
    def apply_patches
      # Apply patches to Redmine core classes
      require_dependency 'redmine_stats/patches/issue_patch'
      require_dependency 'redmine_stats/patches/user_patch'
      require_dependency 'redmine_stats/patches/project_patch'
      
      # Apply hooks
      require_dependency 'redmine_stats/hooks'
    end
  end
end

# Load other files
require File.expand_path('../redmine_stats/utils/stats_calculator', __FILE__)
require File.expand_path('../redmine_stats/utils/chart_helper', __FILE__) 