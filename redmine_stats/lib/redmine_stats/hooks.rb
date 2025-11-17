module RedmineStats
  class Hooks < Redmine::Hook::ViewListener
    # Add CSS and JS to html header
    def view_layouts_base_html_head(context = {})
      stylesheet_link_tag('redmine_stats.css', plugin: 'redmine_stats') +
      javascript_include_tag('stats_charts.js', plugin: 'redmine_stats')
    end
    
    # Potentially add content to the project overview page
    def view_projects_show_right(context = {})
      project = context[:project]
      return unless project.module_enabled?(:stats) && User.current.allowed_to?(:view_stats, project)
      
      # Add a quick stats overview to the project page
      context[:controller].send(:render_to_string, {
        partial: 'stats/project_overview',
        locals: { project: project }
      })
    end
  end
end 