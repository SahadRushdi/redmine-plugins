module TimeAnalyticsHelper
  
  def time_analytics_tabs
    [
      { name: 'individual_dashboard', label: l(:label_individual_dashboard), partial: 'individual_dashboard' },
      { name: 'team_dashboard', label: l(:label_team_dashboard), partial: 'team_dashboard' },
      { name: 'custom_dashboard', label: l(:label_custom_dashboard), partial: 'custom_dashboard' }
    ]
  end

  def current_tab
    params[:tab] || 'individual_dashboard'
  end

  def format_hours(hours)
    return '0.00' if hours.nil? || hours.zero?
    sprintf('%.2f', hours.to_f)
  end

  def format_date_for_grouping(date, grouping)
    case grouping
    when 'daily'
      date.strftime('%Y-%m-%d')
    when 'weekly'
      "Week #{date.strftime('%U')} - #{date.year}"
    when 'monthly'
      date.strftime('%B %Y')
    when 'yearly'
      date.strftime('%Y')
    else
      date.strftime('%Y-%m-%d')
    end
  end

  def time_filter_options
    [
      [l(:label_today), 'today'],
      [l(:label_this_week), 'this_week'],
      [l(:label_this_month), 'this_month'],
      [l(:label_this_year), 'this_year'],
      [l(:label_custom_range), 'custom']
    ]
  end

  def grouping_options
    [
      [l(:label_daily), 'daily'],
      [l(:label_weekly), 'weekly'],
      [l(:label_monthly), 'monthly'],
      [l(:label_yearly), 'yearly']
    ]
  end

  def chart_type_options
    [
      [l(:label_bar_chart), 'bar'],
      [l(:label_line_chart), 'line'],
      [l(:label_pie_chart), 'pie']
    ]
  end

  def per_page_options
    [
      ['10', 10],
      ['25', 25],
      ['50', 50],
      ['100', 100]
    ]
  end

  def time_analytics_page_title
    case params[:action]
    when 'individual_dashboard'
      l(:label_individual_dashboard)
    when 'team_dashboard'
      l(:label_team_dashboard)
    when 'custom_dashboard'
      l(:label_custom_dashboard)
    else
      l(:label_time_analytics)
    end
  end

  def pagination_links(current_page, total_pages, base_params)
    return '' if total_pages <= 1

    links = []
    
    # Previous link
    if current_page > 1
      prev_params = base_params.merge(page: current_page - 1)
      links << link_to('‹ ' + l(:label_previous), 
                       time_analytics_individual_dashboard_path(prev_params), 
                       class: 'pagination-link')
    end
    
    # Page numbers
    start_page = [current_page - 2, 1].max
    end_page = [current_page + 2, total_pages].min
    
    (start_page..end_page).each do |page|
      if page == current_page
        links << content_tag(:span, page, class: 'pagination-current')
      else
        page_params = base_params.merge(page: page)
        links << link_to(page, time_analytics_individual_dashboard_path(page_params), class: 'pagination-link')
      end
    end
    
    # Next link
    if current_page < total_pages
      next_params = base_params.merge(page: current_page + 1)
      links << link_to(l(:label_next) + ' ›', 
                       time_analytics_individual_dashboard_path(next_params), 
                       class: 'pagination-link')
    end
    
    content_tag(:div, links.join(' ').html_safe, class: 'pagination')
  end

  def issue_link_or_text(issue)
    if issue
      link_to "##{issue.id}: #{truncate(issue.subject, length: 50)}", 
              issue_path(issue), 
              class: 'issue-link'
    else
      content_tag(:span, '-', class: 'no-issue')
    end
  end

  def activity_name(activity)
    activity ? activity.name : '-'
  end

  def project_link(project)
    link_to project.name, project_path(project), class: 'project-link'
  end
end