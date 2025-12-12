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

  def format_chart_label(key)
    # Handle different key formats from database grouping
    case key
    when Date, Time, DateTime
      key.strftime('%b %d, %Y')
    when String
      # Handle MySQL YEARWEEK format for weekly grouping
      if key.match?(/^\d{6}$/)
        year = key[0..3].to_i
        week = key[4..5].to_i
        # Date.commercial(year, week, 1) gives Monday. We can use this to represent the week.
        "Week #{week}, #{year}"
      else
        key
      end
    when Integer
      # Handle MySQL year grouping or YEARWEEK
      if key > 999999 # YEARWEEK format (YYYYWW)
        year = key / 100
        week = key % 100
        "Week #{week}, #{year}"
      elsif key > 1000 && key < 3000 # Likely a year
        key.to_s
      else
        key.to_s
      end
    when Array
      # Handle MySQL YEAR(spent_on), MONTH(spent_on) grouping for monthly
      if key.size == 2 && key.all? { |k| k.is_a?(Numeric) }
        year, month = key
        Date.new(year, month, 1).strftime('%b %Y')
      else
        key.join(', ')
      end
    else
      key.to_s
    end
  rescue => e
    # Log error if something goes wrong
    Rails.logger.error "Error formatting chart label for key #{key.inspect}: #{e.message}"
    key.to_s
  end

  def format_period_for_table(key, grouping, from_date, to_date)
    # This helper is used to format the 'period' column in the grouped results table.
    # It provides a more descriptive format for weeks than the chart label.
    
    if grouping == 'weekly'
      date_in_week = nil
      
      # Determine a representative date from the database key
      case key
      when Date, Time, DateTime
        # PostgreSQL/SQLite gives a date object (Monday of the week)
        date_in_week = key.to_date
      when String
        # MySQL can give a string like '202540'
        if key.match?(/^\d{6}$/)
          year = key[0..3].to_i
          week_num = key[4..5].to_i
          # Date.commercial gives the Monday of the ISO week. This is a reliable way to get a date in the correct week.
          date_in_week = Date.commercial(year, week_num, 1)
        end
      when Integer
        # MySQL can also return YEARWEEK as an integer
        if key > 100000 && key.to_s.length == 6
          year = key / 100
          week_num = key % 100
          date_in_week = Date.commercial(year, week_num, 1)
        end
      when Array
        # Handle cases like [2025, 10] for monthly, though we're in the weekly block
        # This is more of a safe fallback
        date_in_week = Date.new(key[0], key[1], 1) rescue nil
      end

      # Fallback if key parsing fails
      return format_chart_label(key) unless date_in_week

      # Assuming weeks start on Sunday for display purposes, as requested.
      # date.wday is 0 for Sunday, 1 for Monday, etc.
      start_of_week = date_in_week - date_in_week.wday
      end_of_week = start_of_week + 6

      # The visible range should not extend beyond the user's selected filter range
      display_start = [start_of_week, from_date].max
      display_end = [end_of_week, to_date].min

      # Use a consistent, clear format for the date range
      "#{display_start.strftime('%m/%d/%Y')} to #{display_end.strftime('%m/%d/%Y')}"
    elsif grouping == 'monthly'
      # The key from the controller is now consistently a Date or a 'YYYY-MM-DD' string
      date = key.is_a?(String) ? Date.parse(key) : key.to_date
      return date.strftime('%B %Y')
    else
      # For daily, yearly, and any other case, use the old chart label format
      format_chart_label(key)
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