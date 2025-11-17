module RedmineStats
  module Utils
    class StatsCalculator
      # Calculate overall project health score (0-100)
      def self.calculate_project_health_score(project, options={})
        # Compute over full lifecycle by default (ignore date filters)
        from = nil
        to = nil
        include_subprojects = options[:include_subprojects].nil? ? true : options[:include_subprojects]
        include_parent_issues = options[:include_parent_issues].nil? ? true : options[:include_parent_issues]
        
        # Get all issues using the comprehensive method that handles nested projects and relationships
        if include_subprojects && include_parent_issues
          # Use the comprehensive method that handles both subprojects and parent/child relationships
          all_issues = project.all_issues_with_subprojects_and_relations(options)
        elsif include_subprojects
          # Use method that only includes subprojects
          all_issues = project.all_issues_with_subprojects
        else
          # Use only direct project issues
          all_issues = project.issues
        end
        
        # Use all issues across lifecycle
        scoped_issues = all_issues
        
        # Count total issues in scope
        total_issues = scoped_issues.count
        
        # Count resolved or closed issues in scope (by updated_on in range if provided)
        resolved_or_closed_scope = all_issues.resolved_or_closed
        resolved_or_closed_issues = resolved_or_closed_scope.count
        
        # Count overdue and open issues (current state)
        open_issues_count = all_issues.open.count
        overdue_issues = all_issues.open
                        .where('due_date < ? AND due_date IS NOT NULL', Date.today).count
        
        # Get average resolution time using the same set of resolved/closed issues
        avg_time = 0
        resolved_issues = resolved_or_closed_scope
        
        if resolved_issues.any?
          # Calculate average resolution time directly
          resolution_times = resolved_issues.map(&:resolution_time).compact
          avg_time = resolution_times.any? ? (resolution_times.sum / resolution_times.size) : 0
        end
        
        # Calculate score components
        resolution_rate = total_issues > 0 ? (resolved_or_closed_issues.to_f / total_issues * 100) : 0
        # Penalize based on proportion among open issues, not all historical issues
        overdue_ratio = open_issues_count > 0 ? (overdue_issues.to_f / open_issues_count.to_f) : 0.0
        overdue_penalty = overdue_ratio * 100
        # Harsher penalty for overdue (non-linear amplification)
        overdue_penalty_adjusted = [[(1 - (1 - overdue_ratio)**1.5) * 100, 0].max, 100].min
        time_factor = avg_time > 0 ? [100 - (avg_time / 86400.0 * 10), 0].max : 100
        
        # Weight and combine components (tighter on overdue)
        weight_resolution = 0.35
        weight_overdue    = 0.45
        weight_time       = 0.20
        score = (resolution_rate * weight_resolution) + ((100 - overdue_penalty_adjusted) * weight_overdue) + (time_factor * weight_time)
        
        # Ensure score is between 0-100
        final_score = [[score, 0].max, 100].min.round(1)
        
        if options[:detailed]
          {
            score: final_score,
            components: {
              resolution_rate: resolution_rate.round(1),
              overdue_penalty: overdue_penalty_adjusted.round(1),
              time_factor: time_factor.round(1)
            },
            metrics: {
              total_issues: total_issues,
              resolved_or_closed_issues: resolved_or_closed_issues,
              overdue_issues: overdue_issues,
              open_issues: open_issues_count,
              avg_resolution_time: avg_time
            }
          }
        else
          final_score
        end
      end
      
      # Calculate user productivity trend
      def self.calculate_user_productivity_trend(user, project=nil, options={})
        from = options[:from] || (Date.today - 90.days)
        to = options[:to] || Date.today
        include_subprojects = options[:include_subprojects].nil? ? true : options[:include_subprojects]
        include_parent_issues = options[:include_parent_issues].nil? ? true : options[:include_parent_issues]
        
        # Update options to include nested project and issue settings
        options = options.merge({
          include_subprojects: include_subprojects,
          include_parent_issues: include_parent_issues
        })
        
        # Determine appropriate interval based on date range
        days_difference = (to - from).to_i
        
        # Choose interval based on date range
        interval = if days_difference <= 7
                     1  # Daily for 1 week or less
                   elsif days_difference <= 30
                     7  # Weekly for 1 month or less
                   elsif days_difference <= 90
                     14 # Bi-weekly for 3 months or less
                   else
                     30 # Monthly for longer periods
                   end
        
        # Create time periods for comparison
        periods = []
        current_end = to
        
        # Generate more data points for better visualization
        while current_end >= from
          current_start = [current_end - interval.days, from].max
          periods.unshift({
            from: current_start,
            to: current_end
          })
          current_end = current_start - 1.day
        end
        
        # Make sure we have at least 3 data points for a meaningful trend
        if periods.size < 3 && days_difference > 3
          # Recalculate with a smaller interval
          smaller_interval = [days_difference / 3, 1].max 
          
          periods = []
          current_end = to
          
          while current_end >= from
            current_start = [current_end - smaller_interval.days, from].max
            periods.unshift({
              from: current_start,
              to: current_end
            })
            current_end = current_start - 1.day
            
            # Break if we have enough periods
            break if periods.size >= 6
          end
        end
        
        # Calculate score for each period with nested project and issue support
        trends = periods.map do |period|
          period_options = options.merge(period)
          {
            period: "#{period[:from].strftime('%Y-%m-%d')} to #{period[:to].strftime('%Y-%m-%d')}",
            score: user.contribution_score(project, period_options)
          }
        end
        
        # Ensure we return a meaningful trend even if there's minimal data
        if trends.empty? || trends.all? { |t| t[:score] == 0 }
          # Return dummy data for visualization
          [{
            period: from.strftime('%Y-%m-%d'),
            score: 0
          }, {
            period: to.strftime('%Y-%m-%d'),
            score: 0
          }]
        else
          trends
        end
      end
      
      # Calculate the most active time periods
      def self.calculate_active_periods(project, options={})
        from = options[:from] || (Date.today - 12.months)
        to = options[:to] || Date.today
        include_subprojects = options[:include_subprojects].nil? ? true : options[:include_subprojects]
        include_parent_issues = options[:include_parent_issues].nil? ? true : options[:include_parent_issues]
        
        # First, get all relevant issues using the comprehensive method
        if include_subprojects && include_parent_issues
          all_issues = project.all_issues_with_subprojects_and_relations(options)
        elsif include_subprojects
          all_issues = project.all_issues_with_subprojects
        else
          all_issues = project.issues
        end
        
        # Get journals for all these issues
        journals = Journal.where(journalized_type: 'Issue', journalized_id: all_issues.pluck(:id))
                   .where('journals.created_on BETWEEN ? AND ?', from, to)
        
        # Group by hour of day
        by_hour = journals.group("HOUR(journals.created_on)").count
                  .transform_keys(&:to_i)
                  .sort_by { |hour, _| hour }
                  .to_h
        
        # Group by day of week (1 = Monday, 7 = Sunday)
        by_weekday = journals.group("DAYOFWEEK(journals.created_on)").count
                     .transform_keys { |day| (day % 7) + 1 }
                     .sort_by { |day, _| day }
                     .to_h
        
        # Return both sets of statistics
        {
          by_hour: by_hour,
          by_weekday: by_weekday
        }
      end
      
      # Return a description of how the health score is calculated
      def self.health_score_formula_description
        {
          resolution_rate: {
            description: "Percentage of issues that have been resolved in the selected time period",
            weight: 0.35,
            calculation: "closed_issues / total_issues * 100"
          },
          overdue_penalty: {
            description: "Penalty for issues that are past their due date",
            weight: 0.45,
            calculation: "100 - amplified overdue penalty (non-linéaire)"
          },
          time_factor: {
            description: "Score based on how quickly issues are resolved",
            weight: 0.2,
            calculation: "100 - (avg_resolution_time_in_days * 10), min 0"
          }
        }
      end

      # Provide a French project state label based on score and overdue ratio
      def self.project_state_label(score, overdue_issues:, total_issues:)
        overdue_ratio = total_issues.to_i > 0 ? (overdue_issues.to_f / total_issues.to_f) : 0.0
        case
        when score >= 85 && overdue_ratio <= 0.05
          "Excellente trajectoire"
        when score >= 70 && overdue_ratio <= 0.15
          "Dans la bonne voie"
        when score >= 50
          "Sous surveillance"
        else
          "En difficulté"
        end
      end
      
      # Return a description of how contribution scores are calculated
      def self.contribution_score_formula_description
        {
          administrative: {
            description: "Sum of all administrative tasks",
            components: {
              issues_created: {
                description: "Issues created by the user",
                weight: 1.0
              },
              issues_updated: {
                description: "Issues updated by the user",
                weight: 1.0
              },
              issues_closed: {
                description: "Issues closed by the user",
                weight: 1.0
              },
              comments: {
                description: "Comments added by the user",
                weight: 1.0
              },
              status_updates: {
                description: "Status updates made by the user",
                weight: 1.0
              }
            }
          },
          technical: {
            description: "Technical contribution based on resolution timing",
            components: {
              on_time_resolutions: {
                description: "Issues resolved before due date",
                weight: 3.0
              },
              not_on_time_resolutions: {
                description: "Issues resolved after due date",
                weight: 1.0
              }
            }
          }
        }
      end
    end
  end
end 