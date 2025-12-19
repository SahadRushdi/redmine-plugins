class TimeAnalyticsController < ApplicationController
  before_action :require_login
  before_action :set_date_range
  before_action :set_grouping
  helper :time_analytics

  def index
    # Default to individual dashboard
    permitted_params = params.permit(:filter, :from, :to, :grouping, :search, :chart_type, :per_page, :page)
    redirect_to time_analytics_individual_dashboard_path(permitted_params)
  end

  def individual_dashboard
    @user = User.current
    @view_mode = params[:view_mode] || 'time_entries'
    
    # Get time entries for the current user with project visibility check
    @time_entries = TimeEntry.joins(:project)
                             .where(user: @user)
                             .where(spent_on: @from..@to)
                             .where(projects: { status: Project::STATUS_ACTIVE })
                             .includes(:project, :issue, :activity)
                             .order('time_entries.spent_on DESC, time_entries.created_on DESC')

    # Apply search filter if present
    if params[:search].present?
      search_term = "%#{params[:search]}%"
      # Use database-agnostic search - ActiveRecord handles case sensitivity based on database
      @time_entries = @time_entries.where(
        "LOWER(projects.name) LIKE LOWER(?) OR LOWER(issues.subject) LIKE LOWER(?) OR LOWER(time_entries.comments) LIKE LOWER(?)",
        search_term, search_term, search_term
      )
    end

    # Calculate totals and statistics
    @total_hours = @time_entries.sum(:hours)
    @entry_count = @time_entries.count
    @avg_hours_per_day = calculate_avg_hours_per_day
    @max_daily_hours = calculate_max_daily_hours
    @min_daily_hours = calculate_min_daily_hours

    @limit = params[:per_page].present? ? params[:per_page].to_i : 25
    @offset = params[:page].present? ? (params[:page].to_i - 1) * @limit : 0

    if @view_mode == 'activity'
      # Generate Activity × Time Period pivot table for ALL groupings (including daily)
      @activity_pivot_data = generate_activity_pivot_table(@time_entries, @grouping)
      @time_periods = @activity_pivot_data[:periods]
      @activities = @activity_pivot_data[:activities]
      @matrix_data = @activity_pivot_data[:matrix]
      @period_totals = @activity_pivot_data[:period_totals]
      @activity_totals = @activity_pivot_data[:activity_totals]
      @grand_total = @activity_pivot_data[:grand_total]
      
      # For pagination, use periods count
      @entry_count = @time_periods.count
      @paginated_periods = @time_periods.slice(@offset, @limit)
      
      # Also generate simple activity summary for daily toggle view
      if @grouping == 'daily'
        grouped_data = group_time_entries(@time_entries, 'activity')
        # Sort by activity name
        sorted_data = grouped_data.sort_by { |activity_name, _| activity_name || 'No Activity' }
        @paginated_entries = sorted_data.slice(@offset, @limit).map do |activity_name, hours|
          Struct.new(:period, :hours).new(activity_name || 'No Activity', hours)
        end
      end
    elsif ['weekly', 'monthly', 'yearly'].include?(@grouping)
      grouped_data = group_time_entries(@time_entries, @grouping)
      @entry_count = grouped_data.count

      # Sort by the key (which is the date/period) to ensure chronological order
      sorted_data = grouped_data.sort_by do |key, _|
        # The key itself (date, year/month array, etc.) is sortable
        key
      end

      @paginated_entries = sorted_data.slice(@offset, @limit).map do |period, hours|
        # Use a Struct for easier access in the view, like an object
        Struct.new(:period, :hours).new(helpers.format_period_for_table(period, @grouping, @from, @to), hours)
      end
    else # Daily grouping
      # This is the original logic for daily entries
      @entry_count = @time_entries.count
      @paginated_entries = @time_entries.limit(@limit).offset(@offset)
    end

    # Generate chart data based on prepared data
    chart_type = params[:chart_type] || 'bar'
    Rails.logger.info "Generating chart with type: #{chart_type}, view_mode: #{@view_mode}, grouping: #{@grouping}"
    
    if @view_mode == 'activity' && ['weekly', 'monthly', 'yearly'].include?(@grouping) && defined?(@activity_pivot_data)
      @chart_data = generate_activity_pivot_chart_data(@activity_pivot_data, chart_type)
    else
      @chart_data = generate_chart_data(@time_entries, @grouping, chart_type, @view_mode)
    end
    
    @total_pages = (@entry_count.to_f / @limit).ceil

    respond_to do |format|
      format.html
      format.json { 
        # Parse the chart data JSON string back to hash for JSON response
        chart_data_hash = JSON.parse(@chart_data)
        render json: { 
          chart_data: chart_data_hash, 
          total_hours: @total_hours,
          chart_type: params[:chart_type] || 'bar'
        } 
      }
    end
  end

  def team_dashboard
    # Placeholder for future implementation
    render plain: "Team Dashboard - Coming Soon"
  end

  def custom_dashboard
    # Placeholder for future implementation
    render plain: "Custom Dashboard - Coming Soon"
  end

  def export_csv
    @user = User.current
    @view_mode = params[:view_mode] || 'time_entries'
    
    @time_entries = TimeEntry.joins(:project)
                             .where(user: @user)
                             .where(spent_on: @from..@to)
                             .where(projects: { status: Project::STATUS_ACTIVE })
                             .includes(:project, :issue, :activity)
                             .order('time_entries.spent_on DESC')

    # Apply search filter if present
    if params[:search].present?
      search_term = "%#{params[:search]}%"
      # Use database-agnostic search - ActiveRecord handles case sensitivity based on database
      @time_entries = @time_entries.where(
        "LOWER(projects.name) LIKE LOWER(?) OR LOWER(issues.subject) LIKE LOWER(?) OR LOWER(time_entries.comments) LIKE LOWER(?)",
        search_term, search_term, search_term
      )
    end

    if @view_mode == 'activity'
      csv_data = export_activity_analysis_to_csv(@time_entries)
      filename = "time_analytics_activity_#{@user.login}_#{@from}_#{@to}.csv"
    else
      csv_data = export_time_entries_to_csv(@time_entries)
      filename = "time_analytics_#{@user.login}_#{@from}_#{@to}.csv"
    end
    
    send_data csv_data, 
              filename: filename,
              type: 'text/csv'
  end

  private

  def set_date_range
    case params[:filter]
    when 'today'
      @from = @to = Date.current
    when 'this_week'
      @from = Date.current.beginning_of_week
      @to = Date.current.end_of_week
    when 'this_month'
      @from = Date.current.beginning_of_month
      @to = Date.current.end_of_month
    when 'this_year'
      @from = Date.current.beginning_of_year
      @to = Date.current.end_of_year
    when 'custom'
      @from = params[:from].present? ? Date.parse(params[:from]) : (Date.current - 30.days)
      @to = params[:to].present? ? Date.parse(params[:to]) : Date.current
    else
      # Default to this week
      params[:filter] = 'this_week'
      @from = Date.current.beginning_of_week
      @to = Date.current.end_of_week
    end
  rescue ArgumentError
    # Handle invalid date format
    @from = Date.current - 30.days
    @to = Date.current
  end

  def set_grouping
    # Store grouping in session for persistence
    if params[:grouping].present?
      session[:time_analytics_grouping] = params[:grouping]
    end
    
    # Use session grouping if no parameter provided
    @grouping = params[:grouping].presence || session[:time_analytics_grouping] || 'daily'
    @grouping = 'daily' unless %w[daily weekly monthly yearly].include?(@grouping)
    
    # Update session with valid grouping
    session[:time_analytics_grouping] = @grouping
  end

  def calculate_avg_hours_per_day
    return 0 if @time_entries.empty?
    
    # Remove order clause to avoid ambiguity in GROUP BY
    days_with_entries = @time_entries.reorder(nil).group(:spent_on).sum(:hours).keys.count
    return 0 if days_with_entries.zero?
    
    (@total_hours / days_with_entries).round(2)
  end

  def calculate_max_daily_hours
    # Remove order clause to avoid ambiguity in GROUP BY
    daily_totals = @time_entries.reorder(nil).group(:spent_on).sum(:hours).values
    daily_totals.max || 0
  end

  def calculate_min_daily_hours
    # Remove order clause to avoid ambiguity in GROUP BY
    daily_totals = @time_entries.reorder(nil).group(:spent_on).sum(:hours).values
    return 0 if daily_totals.empty?
    daily_totals.min
  end

  # Inline Chart Helper methods
  def generate_chart_data(time_entries, grouping, chart_type, view_mode = 'time_entries')
    # Group data by the specified view mode and grouping
    if view_mode == 'activity'
      grouped_data = group_time_entries(time_entries, 'activity')
    else
      grouped_data = group_time_entries(time_entries, grouping)
    end
    
    case chart_type
    when 'pie'
      generate_pie_chart_data(grouped_data, view_mode)
    when 'line'
      generate_line_chart_data(grouped_data, view_mode)
    else
      generate_bar_chart_data(grouped_data, view_mode)
    end
  end

  def group_time_entries(time_entries, grouping)
    # Remove order clause to avoid ambiguity in GROUP BY operations
    base_query = time_entries.reorder(nil)
    
    # Get database adapter to use appropriate date functions
    adapter_name = ActiveRecord::Base.connection.adapter_name.downcase
    
    case grouping
    when 'activity'
      # Group by activity name - join with enumerations table to get activity names
      base_query.joins('LEFT JOIN enumerations ON time_entries.activity_id = enumerations.id')
                .group('enumerations.name')
                .sum(:hours)
    when 'daily'
      base_query.group(:spent_on).sum(:hours)
    when 'weekly'
      if adapter_name.include?('mysql')
        # MySQL: Group by year and week number
        base_query.group('YEARWEEK(spent_on, 1)').sum(:hours)
      elsif adapter_name.include?('postgresql')
        base_query.group('DATE_TRUNC(\'week\', spent_on)').sum(:hours)
      else
        # Fallback for other databases - group by week start date
        base_query.group("DATE(spent_on - ((STRFTIME('%w', spent_on) + 6) % 7) || ' days')").sum(:hours)
      end
    when 'monthly'
      if adapter_name.include?('mysql')
        # MySQL: Group by the first day of the month (YYYY-MM-01)
        base_query.group("DATE_FORMAT(spent_on, '%Y-%m-01')").sum(:hours)
      elsif adapter_name.include?('postgresql')
        base_query.group('DATE_TRUNC(\'month\', spent_on)').sum(:hours)
      else
        # Fallback for other databases (SQLite)
        base_query.group("DATE(spent_on, 'start of month')").sum(:hours)
      end
    when 'yearly'
      if adapter_name.include?('mysql')
        # MySQL: Group by year
        base_query.group('YEAR(spent_on)').sum(:hours)
      elsif adapter_name.include?('postgresql')
        base_query.group('DATE_TRUNC(\'year\', spent_on)').sum(:hours)
      else
        # Fallback for other databases
        base_query.group("DATE(spent_on, 'start of year')").sum(:hours)
      end
    else
      base_query.group(:spent_on).sum(:hours)
    end
  end

  def generate_colors(count)
    colors = [
      '#FF6384', '#36A2EB', '#FFCE56', '#4BC0C0', '#9966FF',
      '#FF9F40', '#8AC249', '#EA5F89', '#00D1B2', '#958AF7'
    ]
    
    if count <= colors.size
      colors.take(count)
    else
      result = colors.dup
      (count - colors.size).times do |i|
        hue = (i * 137.5) % 360
        result << "hsl(#{hue}, 70%, 60%)"
      end
      result
    end
  end

  def generate_pie_chart_data(data_hash, view_mode = 'time_entries')
    return empty_chart_data('pie') if data_hash.empty?

    formatted_labels = if view_mode == 'activity'
      data_hash.keys.map { |key| key || 'No Activity' }
    else
      data_hash.keys.map { |key| helpers.format_period_for_table(key, @grouping, @from, @to) }
    end
    
    # Calculate total for percentage calculation in JavaScript
    total_hours = data_hash.values.sum
    
    chart_data = {
      labels: formatted_labels,
      datasets: [{
        data: data_hash.values,
        backgroundColor: generate_colors(data_hash.size),
        borderWidth: 1,
        borderColor: '#fff'
      }]
    }

    chart_options = {
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        legend: {
          position: 'right',
          labels: {
            padding: 15,
            boxWidth: 12
          }
        }
      },
      # Add total hours for percentage calculation in JavaScript
      total_hours: total_hours
    }

    {
      type: 'pie',
      data: chart_data,
      options: chart_options
    }.to_json.html_safe
  end

  def generate_bar_chart_data(data_hash, view_mode = 'time_entries')
    return empty_chart_data('bar') if data_hash.empty?

    formatted_labels = if view_mode == 'activity'
      data_hash.keys.map { |key| key || 'No Activity' }
    else
      data_hash.keys.map { |key| helpers.format_period_for_table(key, @grouping, @from, @to) }
    end
    
    chart_data = {
      labels: formatted_labels,
      datasets: [{
        label: 'Hours',
        data: data_hash.values,
        backgroundColor: generate_colors(data_hash.size),
        borderWidth: 1
      }]
    }

    chart_options = {
      responsive: true,
      maintainAspectRatio: false,
      scales: {
        y: {
          beginAtZero: true
        },
        x: {
          ticks: {
            maxRotation: 45,
            minRotation: 45
          }
        }
      }
    }

    {
      type: 'bar',
      data: chart_data,
      options: chart_options
    }.to_json.html_safe
  end

  def generate_line_chart_data(data_hash, view_mode = 'time_entries')
    return empty_chart_data('line') if data_hash.empty?

    if view_mode == 'activity'
      # For activity view, sort by activity name
      sorted_data = data_hash.sort_by { |key, _| key || 'No Activity' }
      formatted_labels = sorted_data.map { |key, _| key || 'No Activity' }
    else
      # Sort data by date for proper line chart display
      sorted_data = data_hash.sort_by { |key, _| key.is_a?(Date) ? key : Date.parse(key.to_s) rescue Date.current }
      formatted_labels = sorted_data.map { |key, _| helpers.format_period_for_table(key, @grouping, @from, @to) }
    end
    
    chart_data = {
      labels: formatted_labels,
      datasets: [{
        label: 'Hours',
        data: sorted_data.map { |_, value| value },
        borderColor: '#36a2eb',
        backgroundColor: 'rgba(54, 162, 235, 0.1)',
        fill: true,
        tension: 0.2,
        borderWidth: 2,
        pointRadius: 3,
        pointHoverRadius: 5
      }]
    }

    chart_options = {
      responsive: true,
      maintainAspectRatio: false,
      scales: {
        y: {
          beginAtZero: true
        },
        x: {
          ticks: {
            maxRotation: 45,
            minRotation: 45
          }
        }
      }
    }

    {
      type: 'line',
      data: chart_data,
      options: chart_options
    }.to_json.html_safe
  end

  def empty_chart_data(chart_type)
    {
      type: chart_type,
      data: {
        labels: ['No Data'],
        datasets: [{
          data: [1],
          backgroundColor: ['rgba(200, 200, 200, 0.2)'],
          borderColor: ['rgba(200, 200, 200, 0.6)'],
          borderWidth: 1
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: { display: false }
        }
      }
    }.to_json.html_safe
  end

  # Inline CSV Export methods
  def export_time_entries_to_csv(time_entries)
    require 'csv'
    
    CSV.generate(headers: true) do |csv|
      # Add headers
      csv << ['Date', 'Project', 'Activity', 'Issue', 'Comment', 'Hours']
      
      # Add data rows
      time_entries.each do |entry|
        csv << [
          entry.spent_on.strftime('%Y-%m-%d'),
          entry.project.name,
          entry.activity&.name || '-',
          entry.issue ? "##{entry.issue.id}: #{entry.issue.subject}" : '-',
          entry.comments || '-',
          sprintf('%.2f', entry.hours)
        ]
      end
      
      # Add summary row
      total_hours = time_entries.map { |entry| entry.hours }.sum
      csv << []
      csv << ['TOTAL', '', '', '', '', sprintf('%.2f', total_hours)]
    end
  end

  def export_activity_analysis_to_csv(time_entries)
    require 'csv'
    
    # Group by activity
    grouped_data = group_time_entries(time_entries, 'activity')
    
    CSV.generate(headers: true) do |csv|
      # Add headers
      csv << ['Activity', 'Total Hours']
      
      # Sort by activity name and add data rows
      sorted_data = grouped_data.sort_by { |activity_name, _| activity_name || 'No Activity' }
      sorted_data.each do |activity_name, hours|
        csv << [
          activity_name || 'No Activity',
          sprintf('%.2f', hours)
        ]
      end
      
      # Add summary row
      total_hours = grouped_data.values.sum
      csv << []
      csv << ['TOTAL', sprintf('%.2f', total_hours)]
    end
  end

  def generate_activity_pivot_table(time_entries, grouping)
    Rails.logger.info "Generating activity pivot table for grouping: #{grouping}, entries count: #{time_entries.count}"
    
    # Get all time entries with their details
    entries_with_details = time_entries.includes(:activity).map do |entry|
      period_key = get_activity_period_key(entry.spent_on, grouping)
      activity_name = entry.activity&.name || 'No Activity'
      {
        period_key: period_key,
        activity_name: activity_name,
        hours: entry.hours
      }
    end
    
    # Get unique periods and activities
    periods = entries_with_details.map { |e| e[:period_key] }.uniq.sort
    activities = entries_with_details.map { |e| e[:activity_name] }.uniq.sort
    
    # Initialize matrix with zeros
    matrix_data = {}
    periods.each { |period| matrix_data[period] = {} }
    
    # Populate matrix data
    entries_with_details.each do |entry|
      period = entry[:period_key]
      activity = entry[:activity_name]
      matrix_data[period][activity] ||= 0
      matrix_data[period][activity] += entry[:hours]
    end
    
    # Calculate totals
    period_totals = {}
    activity_totals = {}
    grand_total = 0
    
    periods.each do |period|
      period_totals[period] = activities.sum { |activity| matrix_data[period][activity] || 0 }
      grand_total += period_totals[period]
    end
    
    activities.each do |activity|
      activity_totals[activity] = periods.sum { |period| matrix_data[period][activity] || 0 }
    end
    
    {
      periods: periods.map { |p| format_activity_period_display(p, grouping) },
      activities: activities,
      matrix: matrix_data,
      period_totals: period_totals,
      activity_totals: activity_totals,
      grand_total: grand_total,
      raw_periods: periods # Keep original keys for matrix lookup
    }
  end

  def get_activity_period_key(date, grouping)
    case grouping
    when 'weekly'
      # Use Sunday-based week start to match Time Entries format
      start_of_week = date - date.wday  # Sunday = 0, so this gives Sunday
      start_of_week
    when 'monthly'
      # Use first day of month as key
      Date.new(date.year, date.month, 1)
    when 'yearly'
      # Use first day of year as key
      Date.new(date.year, 1, 1)
    else
      date
    end
  end

  def format_activity_period_display(period_key, grouping)
    case grouping
    when 'weekly'
      # Reuse the same logic as Time Entries section for consistency
      helpers.format_period_for_table(period_key, grouping, @from, @to)
    when 'monthly'
      period_key.strftime('%B %Y') # "October 2025"
    when 'yearly'
      period_key.strftime('%Y')
    else
      period_key.strftime('%Y-%m-%d')
    end
  end

  def generate_activity_pivot_chart_data(pivot_data, chart_type)
    # Use period totals for chart data
    labels = pivot_data[:periods]
    data_values = pivot_data[:raw_periods].map { |period| pivot_data[:period_totals][period] || 0 }
    
    case chart_type
    when 'pie'
      generate_pie_chart_from_data(labels, data_values)
    when 'line'
      generate_line_chart_from_data(labels, data_values)
    else
      generate_bar_chart_from_data(labels, data_values)
    end
  end

  def generate_bar_chart_from_data(labels, data_values)
    chart_data = {
      labels: labels,
      datasets: [{
        label: 'Hours',
        data: data_values,
        backgroundColor: generate_colors(labels.size),
        borderWidth: 1
      }]
    }

    chart_options = {
      responsive: true,
      maintainAspectRatio: false,
      scales: {
        y: {
          beginAtZero: true
        },
        x: {
          ticks: {
            maxRotation: 45,
            minRotation: 45
          }
        }
      }
    }

    {
      type: 'bar',
      data: chart_data,
      options: chart_options
    }.to_json.html_safe
  end

  def generate_line_chart_from_data(labels, data_values)
    chart_data = {
      labels: labels,
      datasets: [{
        label: 'Hours',
        data: data_values,
        borderColor: '#36a2eb',
        backgroundColor: 'rgba(54, 162, 235, 0.1)',
        fill: true,
        tension: 0.2,
        borderWidth: 2,
        pointRadius: 3,
        pointHoverRadius: 5
      }]
    }

    chart_options = {
      responsive: true,
      maintainAspectRatio: false,
      scales: {
        y: {
          beginAtZero: true
        },
        x: {
          ticks: {
            maxRotation: 45,
            minRotation: 45
          }
        }
      }
    }

    {
      type: 'line',
      data: chart_data,
      options: chart_options
    }.to_json.html_safe
  end

  def generate_pie_chart_from_data(labels, data_values)
    # Calculate total for percentage calculation in JavaScript
    total_hours = data_values.sum
    
    chart_data = {
      labels: labels,
      datasets: [{
        data: data_values,
        backgroundColor: generate_colors(labels.size),
        borderWidth: 1,
        borderColor: '#fff'
      }]
    }

    chart_options = {
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        legend: {
          position: 'right',
          labels: {
            padding: 15,
            boxWidth: 12
          }
        }
      },
      # Add total hours for percentage calculation in JavaScript
      total_hours: total_hours
    }

    {
      type: 'pie',
      data: chart_data,
      options: chart_options
    }.to_json.html_safe
  end
end