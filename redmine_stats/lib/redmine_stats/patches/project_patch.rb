module RedmineStats
  module Patches
    module ProjectPatch
      def self.included(base)
        base.class_eval do
          # Helper methods for nested project support
          
          # Get all issues including those from subprojects
          def all_issues_with_subprojects
            # Get all subproject IDs recursively
            project_ids = self_and_descendants.pluck(:id)
            Issue.where(project_id: project_ids)
          end
          
          # Get all issues including those from subprojects and parent/child issues
          def all_issues_with_subprojects_and_relations(options={})
            include_parent_issues = options[:include_parent_issues].nil? ? true : options[:include_parent_issues]
            
            # Start with all issues from this project and subprojects
            issues = all_issues_with_subprojects
            issue_ids = issues.pluck(:id)
            
            # If we need to include parent-child relations
            if include_parent_issues
              # Get all parent issue IDs for issues in our scope
              parent_ids = issues.where.not(parent_id: nil).pluck(:parent_id).uniq
              
              # Find parent issues not in our scope (from other projects)
              outside_parent_issues = Issue.where(id: parent_ids).where.not(id: issue_ids)
              
              # Find child issues that have parents in our scope
              child_issues = Issue.where(parent_id: issue_ids).where.not(id: issue_ids)
              
              # Get grandparent issues (parents of our parents)
              grandparent_ids = outside_parent_issues.where.not(parent_id: nil).pluck(:parent_id).uniq
              grandparent_issues = Issue.where(id: grandparent_ids).where.not(id: issue_ids + outside_parent_issues.pluck(:id))
              
              # Get grandchild issues (children of our children)
              grandchild_issues = Issue.where(parent_id: child_issues.pluck(:id)).where.not(id: issue_ids + child_issues.pluck(:id))
              
              # Combine all related issues
              all_related_ids = issue_ids + 
                               outside_parent_issues.pluck(:id) + 
                               child_issues.pluck(:id) + 
                               grandparent_issues.pluck(:id) + 
                               grandchild_issues.pluck(:id)
              
              # Return the combined query
              return Issue.where(id: all_related_ids)
            end
            
            # If not including related issues, return the original set
            issues
          end
          
          # Project statistics methods
          
          # Get issue counts by status
          def issues_by_status(options={})
            # Determine whether to include subprojects and parent/child issues
            include_subprojects = options[:include_subprojects].nil? ? true : options[:include_subprojects]
            include_parent_issues = options[:include_parent_issues].nil? ? true : options[:include_parent_issues]
            
            # Get the comprehensive set of issues using the all_issues_with_subprojects_and_relations method
            if include_subprojects && include_parent_issues
              issues = all_issues_with_subprojects_and_relations(options)
            elsif include_subprojects
              issues = all_issues_with_subprojects
            else
              issues = self.issues
            end
            
            # Apply date filter if provided
            if options[:from] && options[:to]
              # For historical data, we need to include issues created in the date range
              issues = issues.created_between(options[:from], options[:to])
            end
            
            # Group by status properly with eager loading to prevent N+1 queries
            statuses = {}
            issues.includes(:status).each do |issue|
              status = issue.status
              statuses[status] ||= 0
              statuses[status] += 1
            end
            
            statuses
          end
          
          # Get issue counts by priority
          def issues_by_priority(options={})
            # Determine whether to include subprojects and parent/child issues
            include_subprojects = options[:include_subprojects].nil? ? true : options[:include_subprojects]
            include_parent_issues = options[:include_parent_issues].nil? ? true : options[:include_parent_issues]
            
            # Get the comprehensive set of issues using the all_issues_with_subprojects_and_relations method
            if include_subprojects && include_parent_issues
              issues = all_issues_with_subprojects_and_relations(options)
            elsif include_subprojects
              issues = all_issues_with_subprojects
            else
              issues = self.issues
            end
            
            # Apply date filter if provided
            if options[:from] && options[:to]
              # For historical data, we need to include issues created in the date range
              issues = issues.created_between(options[:from], options[:to])
            end
            
            # Group by priority properly with eager loading to prevent N+1 queries
            priorities = {}
            issues.includes(:priority).each do |issue|
              priority = issue.priority
              priorities[priority] ||= 0
              priorities[priority] += 1
            end
            
            priorities
          end
          
          # Get issue counts by tracker
          def issues_by_tracker(options={})
            # Determine whether to include subprojects and parent/child issues
            include_subprojects = options[:include_subprojects].nil? ? true : options[:include_subprojects]
            include_parent_issues = options[:include_parent_issues].nil? ? true : options[:include_parent_issues]
            
            # Get the comprehensive set of issues using the all_issues_with_subprojects_and_relations method
            if include_subprojects && include_parent_issues
              issues = all_issues_with_subprojects_and_relations(options)
            elsif include_subprojects
              issues = all_issues_with_subprojects
            else
              issues = self.issues
            end
            
            # Apply date filter if provided
            if options[:from] && options[:to]
              # For historical data, we need to include issues created in the date range
              issues = issues.created_between(options[:from], options[:to])
            end
            
            # Group by tracker properly with eager loading to prevent N+1 queries
            trackers = {}
            issues.includes(:tracker).each do |issue|
              tracker = issue.tracker
              trackers[tracker] ||= 0
              trackers[tracker] += 1
            end
            
            trackers
          end
          
          # Get issues created over time
          def issues_created_over_time(options={})
            from = options[:from] || (Date.today - 12.months)
            to = options[:to] || Date.today
            interval = options[:interval] || 'month'
            
            # Determine whether to include subprojects and parent/child issues
            include_subprojects = options[:include_subprojects].nil? ? true : options[:include_subprojects]
            include_parent_issues = options[:include_parent_issues].nil? ? true : options[:include_parent_issues]
            
            # Get the comprehensive set of issues using the all_issues_with_subprojects_and_relations method
            if include_subprojects && include_parent_issues
              issues = all_issues_with_subprojects_and_relations(options)
            elsif include_subprojects
              issues = all_issues_with_subprojects
            else
              issues = self.issues
            end
            
            # Only include issues in the date range
            issues = issues.created_between(from, to)
            
            # Group issues by the specified time interval
            result = {}
            
            case interval
            when 'day'
              # Group by day
              from.upto(to) do |date|
                result[date.to_s] = 0
              end
              
              # Count issues for each day
              issues.each do |issue|
                date = issue.created_on.to_date.to_s
                result[date] ||= 0
                result[date] += 1
              end
            when 'week'
              # Format the week as "YYYY-WW" for better readability
              current_date = from
              while current_date <= to
                week_start = current_date.beginning_of_week
                week_number = current_date.strftime('%W').to_i
                week_key = "#{week_start.strftime('%Y-%m-%d')}, Week #{week_number}"
                
                result[week_key] ||= 0
                current_date += 7.days
              end
              
              # Count issues for each week
              issues.each do |issue|
                date = issue.created_on.to_date
                week_start = date.beginning_of_week
                week_number = date.strftime('%W').to_i
                week_key = "#{week_start.strftime('%Y-%m-%d')}, Week #{week_number}"
                
                result[week_key] ||= 0
                result[week_key] += 1
              end
            when 'month'
              # Group by month
              date = from.beginning_of_month
              while date <= to
                month_key = date.strftime('%Y-%m')
                result[month_key] = 0
                date = date.next_month
              end
              
              # Count issues for each month
              issues.each do |issue|
                month_key = issue.created_on.strftime('%Y-%m')
                result[month_key] ||= 0
                result[month_key] += 1
              end
            end
            
            # Return the result sorted by time
            result.sort_by { |time, _| time }.to_h
          end
          
          # Get top contributors based on contribution score
          def top_contributors(limit=10, options={})
            from = options[:from] || (Date.today - 12.months)
            to = options[:to] || Date.today
            
            # Determine whether to include subprojects
            include_subprojects = options[:include_subprojects].nil? ? true : options[:include_subprojects]
            include_parent_issues = options[:include_parent_issues].nil? ? true : options[:include_parent_issues]
            
            # Get all users involved with this project and its subprojects if requested
            if include_subprojects
              project_ids = self_and_descendants.pluck(:id)
              member_user_ids = Member.where(project_id: project_ids).pluck(:user_id).uniq
            else
              member_user_ids = members.pluck(:user_id)
            end
            
            # Add authors and assignees of issues that might not be members
            issue_query = include_subprojects ? all_issues_with_subprojects : issues
            issue_author_ids = issue_query.pluck(:author_id).uniq.compact
            issue_assignee_ids = issue_query.pluck(:assigned_to_id).uniq.compact
            
            # If we need to include parent/child relations, also get users from related issues
            if include_parent_issues
              # Get related issue IDs (parents or children)
              if include_subprojects
                base_issues = all_issues_with_subprojects
              else
                base_issues = issues
              end
              
              # Get parent issue IDs that aren't in our current scope
              parent_ids = base_issues.where.not(parent_id: nil).pluck(:parent_id).uniq - base_issues.pluck(:id)
              
              # Get child issue IDs that aren't in our current scope
              base_issue_ids = base_issues.pluck(:id)
              child_issues = Issue.where(parent_id: base_issue_ids)
              
              # Get users from related issues
              if parent_ids.any?
                parent_issues = Issue.where(id: parent_ids)
                issue_author_ids += parent_issues.pluck(:author_id).uniq.compact
                issue_assignee_ids += parent_issues.pluck(:assigned_to_id).uniq.compact
              end
              
              if child_issues.any?
                issue_author_ids += child_issues.pluck(:author_id).uniq.compact
                issue_assignee_ids += child_issues.pluck(:assigned_to_id).uniq.compact
              end
            end
            
            # Combine all user IDs
            all_user_ids = (member_user_ids + issue_author_ids + issue_assignee_ids).uniq
            
            # Calculate contribution scores for each user
            scores = User.where(id: all_user_ids).map do |user|
              contributor_options = options.merge(
                include_subprojects: include_subprojects, 
                include_parent_issues: include_parent_issues
              )
              
              {
                user: user,
                score: user.contribution_score(self, contributor_options),
                issues_created: user.issues_created_count(self, contributor_options),
                issues_updated: user.updates_count(self, contributor_options),
                issues_closed: user.closed_issues_count(self, contributor_options)
              }
            end
            
            # Sort by score and limit
            scores.sort_by { |item| -item[:score] }.first(limit)
          end
          
          # Average resolution time for project issues
          def average_resolution_time(options={})
            from = options[:from] || (Date.today - 12.months)
            to = options[:to] || Date.today
            
            # Determine whether to include subprojects and parent/child issues
            include_subprojects = options[:include_subprojects].nil? ? true : options[:include_subprojects]
            include_parent_issues = options[:include_parent_issues].nil? ? true : options[:include_parent_issues]
            
            # Get all relevant issues using our comprehensive method
            if include_subprojects && include_parent_issues
              issues = all_issues_with_subprojects_and_relations(options)
                .resolved_or_closed
                .where('issues.updated_on BETWEEN ? AND ?', from, to)
            elsif include_subprojects
              issues = all_issues_with_subprojects
                .resolved_or_closed
                .where('issues.updated_on BETWEEN ? AND ?', from, to)
            else
              issues = self.issues
                .resolved_or_closed
                .where('issues.updated_on BETWEEN ? AND ?', from, to)
            end
            
            # Calculate average resolution time
            resolution_times = issues.map(&:resolution_time).compact
            resolution_times.any? ? (resolution_times.sum / resolution_times.size) : 0
          end
        end
      end
    end
  end
end

unless Project.included_modules.include?(RedmineStats::Patches::ProjectPatch)
  Project.send(:include, RedmineStats::Patches::ProjectPatch)
end 