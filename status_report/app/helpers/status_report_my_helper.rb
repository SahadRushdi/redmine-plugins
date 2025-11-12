module StatusReportMyHelper
  def render_my_unlogged_time_block(block, settings)
    # Define work week: Monday to Friday
    today = Date.today
    
    # Find the Monday of the current week
    monday = today - (today.wday - 1) % 7
    monday = monday - 7 if today.wday == 0 # Adjust if today is Sunday
    
    # Friday is 4 days after Monday
    friday = monday + 4
    
    # Expected hours per day
    hours_per_day = 8
    
    # Calculate total expected hours (5 days * 8 hours)
    expected_hours = 5 * hours_per_day
    
    # Query total hours logged by current user for this week (Monday to Friday)
    logged_hours = TimeEntry.where(user_id: User.current.id)
                            .where('spent_on >= ? AND spent_on <= ?', monday, friday)
                            .sum(:hours)
    
    # Calculate unlogged hours
    unlogged_hours = expected_hours - logged_hours
    unlogged_hours = 0 if unlogged_hours < 0
    
    # Build hash of days with logged hours
    days_to_log = {}
    (monday..friday).each do |date|
      day_logged = TimeEntry.where(user_id: User.current.id, spent_on: date).sum(:hours)
      days_to_log[date] = day_logged
    end
    
    render :partial => 'my/blocks/my_unlogged_time', 
           :locals => {
             :block => block,
             :unlogged_hours => unlogged_hours,
             :expected_hours => expected_hours,
             :logged_hours => logged_hours,
             :days_to_log => days_to_log
           }
  end
end
