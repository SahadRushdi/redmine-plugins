class StatsController < ApplicationController
  before_action :find_project_by_project_id, except: [:global_overview]
  before_action :authorize, except: [:global_overview]
  before_action :require_admin, only: [:global_overview]
  before_action :set_nested_options
  
  helper :sort
  include SortHelper
  
  def index
    @from = params[:from].present? ? Date.parse(params[:from]) : (Date.today - 30.days)
    @to = params[:to].present? ? Date.parse(params[:to]) : Date.today
    
    # Get all issues using the comprehensive method to ensure nested projects and related issues are included
    all_issues = @project.all_issues_with_subprojects_and_relations(
      from: @from,
      to: @to,
      include_subprojects: @include_subprojects,
      include_parent_issues: @include_parent_issues
    )
    
    # Calculate issue counts based on the comprehensive set
    # Counts should cover the entire project lifecycle (ignore date filters) and include subprojects
    scoped_all = all_issues
    @total_issues = scoped_all.count
    @open_issues_count = scoped_all.open.count
    @closed_issues_count = scoped_all.closed.count
    # Compute resolved-only: statuses that look like "resolved" but are not marked closed
    closed_status_ids = IssueStatus.where(is_closed: true).pluck(:id)
    resolved_keywords = %w(resolved résolu resolu solucionado solucionada solved erledigt abgeschlossen risolto risolta resolvido resolvida)
    resolved_only_ids = IssueStatus.all.select { |s| resolved_keywords.any? { |k| s.name.to_s.downcase.include?(k) } && !s.is_closed }.map(&:id)
    @resolved_issues_count = scoped_all.where(status_id: resolved_only_ids).count
    
    # Calculate health score
    @health_score = RedmineStats::Utils::StatsCalculator.calculate_project_health_score(
      @project, 
      include_subprojects: @include_subprojects,
      include_parent_issues: @include_parent_issues
    )
    
    # Get top contributors
    @top_contributors = @project.top_contributors(
      10, 
      from: @from, 
      to: @to, 
      include_subprojects: @include_subprojects,
      include_parent_issues: @include_parent_issues
    )
    
    # Issues statistics with consistent nested options
    @issues_by_status = @project.issues_by_status(
      from: @from, 
      to: @to,
      include_subprojects: @include_subprojects,
      include_parent_issues: @include_parent_issues
    )
    
    @issues_by_priority = @project.issues_by_priority(
      from: @from, 
      to: @to,
      include_subprojects: @include_subprojects,
      include_parent_issues: @include_parent_issues
    )
    
    @issues_by_tracker = @project.issues_by_tracker(
      from: @from, 
      to: @to,
      include_subprojects: @include_subprojects,
      include_parent_issues: @include_parent_issues
    )
    
    # Get issues created over time
    @issues_created_over_time = @project.issues_created_over_time(
      from: @from, 
      to: @to, 
      interval: params[:interval] || 'month',
      include_subprojects: @include_subprojects,
      include_parent_issues: @include_parent_issues
    )
    
    # Prepare chart data
    @status_chart_data = RedmineStats::Utils::ChartHelper.generate_pie_chart_data(
      @issues_by_status, 
      { title: l(:label_issues_by_status) }
    ).to_json
    
    @priority_chart_data = RedmineStats::Utils::ChartHelper.generate_pie_chart_data(
      @issues_by_priority, 
      { title: l(:label_issues_by_priority) }
    ).to_json
    
    @tracker_chart_data = RedmineStats::Utils::ChartHelper.generate_pie_chart_data(
      @issues_by_tracker, 
      { title: l(:label_issues_by_tracker) }
    ).to_json
    
    @issues_trend_chart_data = RedmineStats::Utils::ChartHelper.generate_line_chart_data(
      @issues_created_over_time, 
      { 
        title: l(:label_issues_trend),
        dataset_label: l(:label_issues_created)
      }
    ).to_json
  end
  
  def user_reports
    @user = User.find(params[:user_id]) if params[:user_id].present?
    @from = params[:from].present? ? Date.parse(params[:from]) : (Date.today - 30.days)
    @to = params[:to].present? ? Date.parse(params[:to]) : Date.today
    
    # Get all active users in the project if no specific user selected
    if @include_subprojects
      project_ids = @project.self_and_descendants.pluck(:id)
      all_users = Member.where(project_id: project_ids).map(&:user).compact.uniq
      
      # Get all users involved in issues (authors, assignees) for consistency
      all_issues = @project.all_issues_with_subprojects_and_relations(
        from: @from,
        to: @to,
        include_subprojects: @include_subprojects,
        include_parent_issues: @include_parent_issues
      )
      
      author_ids = all_issues.pluck(:author_id).uniq.compact
      assignee_ids = all_issues.pluck(:assigned_to_id).uniq.compact
      
      # Combine all user IDs
      all_user_ids = (all_users.map(&:id) + author_ids + assignee_ids).uniq
      @users = User.where(id: all_user_ids).sort_by(&:name)
    else
      @users = @project.members.map(&:user).compact.sort_by(&:name)
    end
    
    if @user
      # Get user statistics with consistent nested options
      user_options = {
        from: @from, 
        to: @to, 
        include_subprojects: @include_subprojects,
        include_parent_issues: @include_parent_issues
      }
      
      # Ensure contribution calculations include nested projects and parent/child issues
      @issues_created = @user.issues_created_count(@project, user_options) || 0
      # Count updates instead of assigned
      @issues_updated = @user.updates_count(@project, user_options) || 0
      @issues_closed = @user.closed_issues_count(@project, user_options) || 0
      @contribution_score = @user.contribution_score(@project, user_options) || 0
      @avg_resolution_time = @user.average_resolution_time(@project, user_options) || 0
      
      # Log values for debugging
      Rails.logger.info "User: #{@user.name}, Score: #{@contribution_score}, Options: #{user_options.inspect}"
      
      # Get detailed contribution breakdown with safe fallbacks for nil values
      begin
        @contribution_details = @user.contribution_details(@project, user_options)
        
        # Log the returned contribution details
        Rails.logger.info "Contribution details: #{@contribution_details.inspect}"
        
        # Ensure we have default values for any possible nil components
        @contribution_details ||= { components: {}, total: 0 }
        @contribution_details[:components] ||= {}
        @contribution_details[:components][:administrative] ||= { value: 0, count: 0, weight: 1, breakdown: {} }
        @contribution_details[:components][:administrative][:breakdown] ||= { created: 0, assigned: 0, closed: 0, comments: 0, status_updates: 0 }
        @contribution_details[:components][:technical] ||= { value: 0, count: 0, weight: 1, breakdown: {} }
        @contribution_details[:components][:technical][:breakdown] ||= { on_time: { count: 0, weight: 0 }, not_on_time: { count: 0, weight: 0 } }
        
        # Use the calculated contribution score instead of the one from details
        @contribution_details[:total] = @contribution_score
      rescue => e
        Rails.logger.error "Error calculating contribution details: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        @contribution_details = { 
          components: {
            administrative: { value: 0, count: 0, weight: 1, breakdown: { created: 0, assigned: 0, closed: 0, comments: 0, status_updates: 0 } },
            technical: { value: 0, count: 0, weight: 1, breakdown: { on_time: { count: 0, weight: 0 }, not_on_time: { count: 0, weight: 0 } } }
          },
          total: @contribution_score || 0
        }
      end
      
      # Get productivity trend
      @productivity_trend = RedmineStats::Utils::StatsCalculator.calculate_user_productivity_trend(
        @user, 
        @project, 
        from: @from, 
        to: @to,
        include_subprojects: @include_subprojects,
        include_parent_issues: @include_parent_issues
      )
      
      # Prepare chart data
      @contribution_chart_data = RedmineStats::Utils::ChartHelper.generate_radar_chart_data(
        {
          l(:label_issues_created) || 'Tickets créés' => @issues_created,
          (l(:label_issues_updated) rescue 'Tickets modifiés') => @issues_updated,
          l(:label_issues_closed) || 'Tickets fermés' => @issues_closed,
          l(:label_contribution_score) || 'Score de contribution' => (@contribution_score / 10.0).round(1) # Scale down for radar chart
        },
        { 
          title: l(:label_user_contribution) || "Contribution de l'utilisateur",
          dataset_label: @user.name
        }
      ).to_json
      
      @productivity_chart_data = RedmineStats::Utils::ChartHelper.generate_productivity_trend_chart_data(
        @productivity_trend.map { |p| [p[:period], p[:score]] }.to_h,
        { 
          title: l(:label_productivity_trend) || "Tendance de productivité",
          dataset_label: @user.name
        }
      ).to_json
    else
      # Compare all users
      user_options = {
        from: @from, 
        to: @to, 
        include_subprojects: @include_subprojects,
        include_parent_issues: @include_parent_issues
      }
      
      # Get a comprehensive list of all users involved with the project
      if @include_subprojects
        project_ids = @project.self_and_descendants.pluck(:id)
        member_user_ids = Member.where(project_id: project_ids).pluck(:user_id).uniq
      else
        member_user_ids = @project.members.pluck(:user_id)
      end
      
      # Add issue authors and assignees who may not be members
      issue_query = @include_subprojects ? @project.all_issues_with_subprojects : @project.issues
      issue_author_ids = issue_query.pluck(:author_id).uniq.compact
      issue_assignee_ids = issue_query.pluck(:assigned_to_id).uniq.compact
      
      # Add users from parent/child issues if needed
      if @include_parent_issues
        # Get base issues
        if @include_subprojects
          base_issues = @project.all_issues_with_subprojects
        else
          base_issues = @project.issues
        end
        
        # Get parent issues not in our scope
        parent_ids = base_issues.where.not(parent_id: nil).pluck(:parent_id).uniq - base_issues.pluck(:id)
        if parent_ids.any?
          parent_issues = Issue.where(id: parent_ids)
          issue_author_ids += parent_issues.pluck(:author_id).uniq.compact
          issue_assignee_ids += parent_issues.pluck(:assigned_to_id).uniq.compact
        end
        
        # Get child issues not in our scope
        child_issues = Issue.where(parent_id: base_issues.pluck(:id))
        if child_issues.any?
          issue_author_ids += child_issues.pluck(:author_id).uniq.compact
          issue_assignee_ids += child_issues.pluck(:assigned_to_id).uniq.compact
        end
      end
      
      # Combine all user IDs
      all_user_ids = (member_user_ids + issue_author_ids + issue_assignee_ids).uniq
      
      @user_stats = User.where(id: all_user_ids).map do |user|
        {
          user: user,
          issues_created: user.issues_created_count(@project, user_options),
          issues_updated: user.updates_count(@project, user_options),
          issues_closed: user.closed_issues_count(@project, user_options),
          contribution_score: user.contribution_score(@project, user_options)
        }
      end.sort_by { |stats| -stats[:contribution_score] }
      
      # Prepare comparison chart data
      @users_comparison_chart_data = RedmineStats::Utils::ChartHelper.generate_bar_chart_data(
        @user_stats.map { |stats| [stats[:user].name, stats[:contribution_score]] }.to_h,
        { 
          title: l(:label_user_comparison),
          dataset_label: l(:label_contribution_score)
        }
      ).to_json
    end
  end
  
  def project_reports
    @from = params[:from].present? ? Date.parse(params[:from]) : (Date.today - 30.days)
    @to = params[:to].present? ? Date.parse(params[:to]) : Date.today
    @interval = params[:interval] || 'month'
    
    # Get issue statistics over time
    @issues_created_over_time = @project.issues_created_over_time(
      from: @from, 
      to: @to, 
      interval: @interval,
      include_subprojects: @include_subprojects,
      include_parent_issues: @include_parent_issues
    )
    
    # Active periods
    @active_periods = RedmineStats::Utils::StatsCalculator.calculate_active_periods(
      @project, 
      from: @from, 
      to: @to,
      include_subprojects: @include_subprojects,
      include_parent_issues: @include_parent_issues
    )
    
    # Historical snapshots
    @snapshots = StatsSnapshot.for_project(@project.id).of_type('project_summary').recent(12)
    
    # Get detailed health score data
    @detailed_health = RedmineStats::Utils::StatsCalculator.calculate_project_health_score(
      @project, 
      from: @from, 
      to: @to, 
      detailed: true,
      include_subprojects: @include_subprojects,
      include_parent_issues: @include_parent_issues
    )
    
    # Prepare chart data
    @issues_trend_chart_data = RedmineStats::Utils::ChartHelper.generate_line_chart_data(
      @issues_created_over_time, 
      { 
        title: l(:label_issues_trend),
        dataset_label: l(:label_issues_created)
      }
    ).to_json
    
    @active_hours_chart_data = RedmineStats::Utils::ChartHelper.generate_bar_chart_data(
      @active_periods[:by_hour],
      { 
        title: l(:label_active_hours),
        dataset_label: l(:label_activity_count)
      }
    ).to_json
    
    @active_days_chart_data = RedmineStats::Utils::ChartHelper.generate_bar_chart_data(
      @active_periods[:by_weekday].transform_keys { |d| Date::DAYNAMES[d % 7] },
      { 
        title: l(:label_active_days),
        dataset_label: l(:label_activity_count)
      }
    ).to_json
    
    # Create health components chart data
    @health_components_data = RedmineStats::Utils::ChartHelper.generate_bar_chart_data(
      {
        l(:text_resolution_rate) || "Taux de résolution" => @detailed_health[:components][:resolution_rate],
        l(:text_overdue_issues) || "Gestion des échéances" => 100 - @detailed_health[:components][:overdue_penalty],
        l(:text_resolution_time) || "Temps de résolution" => @detailed_health[:components][:time_factor]
      },
      {
        title: l(:label_health_score) || "Score de santé",
        dataset_label: l(:label_health_components) || "Composantes du score",
        use_value_colors: true,
        max_value: 100
      }
    ).to_json
    
    if @snapshots.any?
      @health_trend_data = RedmineStats::Utils::ChartHelper.generate_line_chart_data(
        @snapshots.map { |s| [s.snapshot_date.to_s, s.data['health_score']] }.to_h,
        { 
          title: l(:label_health_trend),
          dataset_label: l(:label_health_score)
        }
      ).to_json
    end
  end
  
  def issue_reports
    @from = params[:from].present? ? Date.parse(params[:from]) : (Date.today - 30.days)
    @to = params[:to].present? ? Date.parse(params[:to]) : Date.today
    
    # Get average resolution time
    @avg_resolution_time = @project.average_resolution_time(
      from: @from, 
      to: @to,
      include_subprojects: @include_subprojects,
      include_parent_issues: @include_parent_issues
    )
    
    # Get issues with longest resolution time
    if @include_subprojects
      project_ids = @project.self_and_descendants.pluck(:id)
      issues_scope = Issue.where(project_id: project_ids).resolved_or_closed
    else
      issues_scope = @project.issues.resolved_or_closed
    end
    
    issues_scope = issues_scope.where('issues.updated_on BETWEEN ? AND ?', @from, @to)
    
    # Add parent/child issues if requested
    if @include_parent_issues
      # Get all issue IDs in our base scope
      base_issue_ids = issues_scope.pluck(:id)
      
      # Get child issues of issues in our scope
      child_issues_scope = Issue.where(parent_id: base_issue_ids)
                              .resolved_or_closed
                              .where('issues.updated_on BETWEEN ? AND ?', @from, @to)
      
      # Get parent issues of issues in our scope
      parent_ids = issues_scope.where.not(parent_id: nil).pluck(:parent_id).uniq
      parent_issues_scope = Issue.where(id: parent_ids)
                               .resolved_or_closed
                               .where('issues.updated_on BETWEEN ? AND ?', @from, @to)
      
      # Combine all issue IDs
      all_issue_ids = (base_issue_ids + child_issues_scope.pluck(:id) + parent_issues_scope.pluck(:id)).uniq
      
      # Create a new scope with all related issues
      issues_scope = Issue.where(id: all_issue_ids)
    end
    
    # Load all issues into memory
    issues = issues_scope.to_a
    
    # Filter only those with resolution time
    issues_with_resolution = issues.select { |issue| issue.resolution_time }
    
    # Sort by resolution time (descending) and take top 10
    @longest_issues = issues_with_resolution.sort_by { |issue| -issue.resolution_time.to_i }.first(10)
    
    # Get issue creation to resolution time distribution
    @resolution_distribution = {}
    
    # Group issues by resolution time in days
    issues_with_resolution.each do |issue|
      days = (issue.resolution_time / 86400.0).ceil
      days_group = if days <= 1
        '1 day'
      elsif days <= 3
        '2-3 days'
      elsif days <= 7
        '4-7 days'
      elsif days <= 14
        '8-14 days'
      elsif days <= 30
        '15-30 days'
      else
        '30+ days'
      end
      
      @resolution_distribution[days_group] ||= 0
      @resolution_distribution[days_group] += 1
    end
    
    # Prepare chart data
    @resolution_chart_data = RedmineStats::Utils::ChartHelper.generate_pie_chart_data(
      @resolution_distribution, 
      { title: l(:label_resolution_time_distribution) }
    ).to_json
  end
  
  def global_overview
    @projects = Project.active.has_module(:stats).to_a
    
    # Initialize counters for global stats
    @total_issues = 0
    @resolved_issues = 0
    @open_issues = 0
    @closed_issues = 0
    
    # Comprehensive issue counts with support for nested hierarchies
    @projects.each do |project|
      # Use the comprehensive method to get all related issues
      all_issues = project.all_issues_with_subprojects_and_relations(
        include_subprojects: true,
        include_parent_issues: true
      )
      
      # Add to global totals, ensuring we don't double count
      @total_issues += all_issues.count
      @open_issues += all_issues.open.count
      @resolved_issues += (all_issues.resolved_or_closed.count - all_issues.closed.count)
      @closed_issues += all_issues.closed.count
    end
    
    # Adjust for double counting across projects
    all_issue_ids = Set.new
    parent_child_map = {}
    
    @projects.each do |project|
      issues = project.all_issues_with_subprojects_and_relations(
        include_subprojects: true,
        include_parent_issues: true
      )
      
      # Track all issue IDs and parent-child relationships
      issues.each do |issue|
        all_issue_ids.add(issue.id)
        if issue.parent_id
          parent_child_map[issue.parent_id] ||= []
          parent_child_map[issue.parent_id] << issue.id
        end
      end
    end
    
    # Count unique issues
    @total_issues = all_issue_ids.size
    
    # Recalculate status counts for unique issues
    @open_issues = Issue.where(id: all_issue_ids.to_a).open.count
    @resolved_issues = Issue.where(id: all_issue_ids.to_a).resolved_or_closed.count - Issue.where(id: all_issue_ids.to_a).closed.count
    @closed_issues = Issue.where(id: all_issue_ids.to_a).closed.count
    
    # Top projects by total activity (including subprojects and child issues)
    project_activity = {}
    
    @projects.each do |project|
      # Get all related issues
      all_issues = project.all_issues_with_subprojects_and_relations(
        include_subprojects: true,
        include_parent_issues: true
      )
      
      # Total count
      project_activity[project] = all_issues.count
    end
    
    @top_projects = project_activity.sort_by { |_, count| -count }.first(10).to_h
    
    # Calculate top users globally with support for nested issues
    user_activity = {}
    User.active.each do |user|
      # Use a Set to ensure we don't double count issues
      user_issues = Set.new
      
      # Issues created by this user across all projects
      issue_ids = Issue.where(author_id: user.id).pluck(:id)
      user_issues.merge(issue_ids)
      
      # Issues updated by this user (journal entries on issues)
      updated_issue_ids = Journal.where(user_id: user.id, journalized_type: 'Issue').pluck(:journalized_id)
      user_issues.merge(updated_issue_ids)
      
      # Add parent and child issues
      parent_ids = Issue.where(id: user_issues.to_a).where.not(parent_id: nil).pluck(:parent_id)
      user_issues.merge(parent_ids)
      
      child_ids = Issue.where(parent_id: user_issues.to_a).pluck(:id)
      user_issues.merge(child_ids)
      
      # Count status changes by this user
      status_updates = Journal.joins(:details)
                       .where(user_id: user.id)
                       .where("journal_details.property = 'attr' AND journal_details.prop_key = 'status_id'")
                       .count
      
      # Count comments by this user
      comments = Journal.where(user_id: user.id)
                 .where("notes IS NOT NULL AND notes != ''")
                 .count
      
      # Calculate total activity score
      user_activity[user] = user_issues.size + status_updates + comments
    end
    
    @top_users = user_activity.sort_by { |_, score| -score }.first(10).to_h
    
    # Prepare chart data
    @projects_chart_data = RedmineStats::Utils::ChartHelper.generate_bar_chart_data(
      @top_projects.map { |project, count| [project.name, count] }.to_h,
      { 
        title: l(:label_top_projects),
        dataset_label: l(:label_issues_count)
      }
    ).to_json
    
    @users_chart_data = RedmineStats::Utils::ChartHelper.generate_bar_chart_data(
      @top_users.map { |user, score| [user.name, score] }.to_h,
      { 
        title: l(:label_top_users),
        dataset_label: l(:label_activity_score)
      }
    ).to_json
    
    # Add issues by status chart for global overview
    statuses = IssueStatus.all
    status_counts = {}
    
    statuses.each do |status|
      count = Issue.where(id: all_issue_ids.to_a, status_id: status.id).count
      status_counts[status.name] = count if count > 0
    end
    
    @global_status_chart_data = RedmineStats::Utils::ChartHelper.generate_pie_chart_data(
      status_counts,
      {
        title: l(:label_issues_by_status)
      }
    ).to_json
    
    # Add resolved vs. open distribution
    @issue_distribution_data = RedmineStats::Utils::ChartHelper.generate_pie_chart_data(
      {
        l(:label_open_issues) => @open_issues,
        l(:label_resolved_issues) => @resolved_issues,
        l(:label_closed_issues) => @closed_issues
      },
      {
        title: l(:label_issue_distribution)
      }
    ).to_json
  end
  
  private
  
  def set_nested_options
    # Default to including subprojects and parent/child issues unless explicitly set to false
    @include_subprojects = params[:include_subprojects].nil? ? true : (params[:include_subprojects] == 'true')
    @include_parent_issues = params[:include_parent_issues].nil? ? true : (params[:include_parent_issues] == 'true')
    
    # Add these options to params to ensure they're passed to all helper methods
    params[:include_subprojects] = @include_subprojects 
    params[:include_parent_issues] = @include_parent_issues
  end
end 