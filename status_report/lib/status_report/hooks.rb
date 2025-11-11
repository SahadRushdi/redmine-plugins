# frozen_string_literal: true

module StatusReport
  class Hooks < Redmine::Hook::ViewListener
    # Render widget on project overview page (left side)
    def view_projects_show_left(context = {})
      project = context[:project]
      return '' unless project
      
      # Get 5 most recently updated issues
      recent_issues = project.issues
                             .visible
                             .includes(:status, :tracker)
                             .order('issues.updated_on DESC')
                             .limit(5)
      
      context[:controller].send(:render_to_string, {
        :partial => 'reports/recent_issues_widget_box',
        :locals => { :project => project, :recent_issues => recent_issues }
      })
    end
  end
end
