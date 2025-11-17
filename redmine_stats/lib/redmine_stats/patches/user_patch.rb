module RedmineStats
  module Patches
    module UserPatch
      def self.included(base)
        base.class_eval do
          # Add methods for user statistics
          
          # Count issues created by the user in a project
          def issues_created_count(project=nil, options={})
            # Extract the nested options
            include_subprojects = options[:include_subprojects].nil? ? true : options[:include_subprojects]
            include_parent_issues = options[:include_parent_issues].nil? ? true : options[:include_parent_issues]
            
            # Start with issues authored by this user
            base_query = Issue.by_author(id)
            
            if project
              if include_subprojects && include_parent_issues
                # Get all project issues including related ones
                project_issues = project.all_issues_with_subprojects_and_relations(options)
                base_query = base_query.where(id: project_issues.pluck(:id))
              elsif include_subprojects
                # Get all issues from the project and its subprojects
                project_ids = project.self_and_descendants.pluck(:id)
                base_query = base_query.where(project_id: project_ids)
              else
                # Just the current project
                base_query = base_query.where(project_id: project.id)
              end
            end
            
            # Apply date range filter if provided
            if options[:from] && options[:to]
              base_query = base_query.created_between(options[:from], options[:to])
            end
            
            base_query.count
          end
          
          # Count issue updates made by the user (any journal entry on issues)
          def updates_count(project=nil, options={})
            from = options[:from] || (Date.today - 12.months)
            to = options[:to] || Date.today
            
            # Extract the nested options
            include_subprojects = options[:include_subprojects].nil? ? true : options[:include_subprojects]
            include_parent_issues = options[:include_parent_issues].nil? ? true : options[:include_parent_issues]
            
            journals = Journal.where(user_id: id, journalized_type: 'Issue')
                       .where('journals.created_on BETWEEN ? AND ?', from, to)
            
            if project
              if include_subprojects && include_parent_issues
                project_issues = project.all_issues_with_subprojects_and_relations(options)
                journals = journals.where(journalized_id: project_issues.pluck(:id))
              elsif include_subprojects
                project_ids = project.self_and_descendants.pluck(:id)
                journals = journals.joins(:issue).where(issues: { project_id: project_ids })
              else
                journals = journals.joins(:issue).where(issues: { project_id: project.id })
              end
            end
            
            journals.count
          end
          
          # Count closed issues by the user
          def closed_issues_count(project=nil, options={})
            from = options[:from] || (Date.today - 12.months)
            to = options[:to] || Date.today
            
            # Extract the nested options
            include_subprojects = options[:include_subprojects].nil? ? true : options[:include_subprojects]
            include_parent_issues = options[:include_parent_issues].nil? ? true : options[:include_parent_issues]
            
            # Find issues closed by this user through journal entries
            journals = Journal.joins(:details).where(user_id: id)
              .where("journal_details.property = 'attr' AND journal_details.prop_key = 'status_id'")
              .where("journal_details.value IN (?)", IssueStatus.where(is_closed: true).pluck(:id).map(&:to_s))
              .where('journals.created_on BETWEEN ? AND ?', from, to)
            
            if project
              if include_subprojects && include_parent_issues
                # Get all project issues including related ones
                project_issues = project.all_issues_with_subprojects_and_relations(options)
                journals = journals.where(journalized_id: project_issues.pluck(:id), journalized_type: 'Issue')
              elsif include_subprojects
                # Get all issues from the project and its subprojects
                project_ids = project.self_and_descendants.pluck(:id)
                journals = journals.joins(:issue).where(issues: { project_id: project_ids })
              else
                # Just the current project
                journals = journals.joins(:issue).where(issues: { project_id: project.id })
              end
            end
            
            # Count unique issues
            journals.select("DISTINCT journalized_id").count
          end
          
          # Count comments added by the user
          def comments_count(project=nil, options={})
            from = options[:from] || (Date.today - 12.months)
            to = options[:to] || Date.today
            
            # Extract the nested options
            include_subprojects = options[:include_subprojects].nil? ? true : options[:include_subprojects]
            include_parent_issues = options[:include_parent_issues].nil? ? true : options[:include_parent_issues]
            
            # Find comments added by this user
            journals = Journal.where(user_id: id)
              .where("notes IS NOT NULL AND notes != ''")
              .where('journals.created_on BETWEEN ? AND ?', from, to)
            
            if project
              if include_subprojects && include_parent_issues
                # Get all project issues including related ones
                project_issues = project.all_issues_with_subprojects_and_relations(options)
                journals = journals.where(journalized_id: project_issues.pluck(:id), journalized_type: 'Issue')
              elsif include_subprojects
                # Get all issues from the project and its subprojects
                project_ids = project.self_and_descendants.pluck(:id)
                journals = journals.joins(:issue).where(issues: { project_id: project_ids })
              else
                # Just the current project
                journals = journals.joins(:issue).where(issues: { project_id: project.id })
              end
            end
            
            journals.count
          end
          
          # Count status updates by user (measure of activity/involvement)
          def status_updates_count(project=nil, options={})
            from = options[:from] || (Date.today - 12.months)
            to = options[:to] || Date.today
            
            # Extract the nested options
            include_subprojects = options[:include_subprojects].nil? ? true : options[:include_subprojects]
            include_parent_issues = options[:include_parent_issues].nil? ? true : options[:include_parent_issues]
            
            # Find status updates made by this user
            journals = Journal.joins(:details).where(user_id: id)
              .where("journal_details.property = 'attr' AND journal_details.prop_key = 'status_id'")
              .where('journals.created_on BETWEEN ? AND ?', from, to)
            
            if project
              if include_subprojects && include_parent_issues
                # Get all project issues including related ones
                project_issues = project.all_issues_with_subprojects_and_relations(options)
                journals = journals.where(journalized_id: project_issues.pluck(:id), journalized_type: 'Issue')
              elsif include_subprojects
                # Get all issues from the project and its subprojects
                project_ids = project.self_and_descendants.pluck(:id)
                journals = journals.joins(:issue).where(issues: { project_id: project_ids })
              else
                # Just the current project
                journals = journals.joins(:issue).where(issues: { project_id: project.id })
              end
            end
            
            journals.count
          end
          
          # Count on-time resolutions (issues that were resolved before their due date)
          def on_time_resolutions_count(project=nil, options={})
            from = options[:from] || (Date.today - 12.months)
            to = options[:to] || Date.today
            
            # Extract the nested options
            include_subprojects = options[:include_subprojects].nil? ? true : options[:include_subprojects]
            include_parent_issues = options[:include_parent_issues].nil? ? true : options[:include_parent_issues]
            
            # Find closed issues that had a due date and were closed before or on that date
            # First find the journals that closed issues
            closing_journals = Journal.joins(:details).where(user_id: id)
              .where("journal_details.property = 'attr' AND journal_details.prop_key = 'status_id'")
              .where("journal_details.value IN (?)", IssueStatus.where(is_closed: true).pluck(:id).map(&:to_s))
              .where('journals.created_on BETWEEN ? AND ?', from, to)
              
            if project
              if include_subprojects && include_parent_issues
                # Get all project issues including related ones
                project_issues = project.all_issues_with_subprojects_and_relations(options)
                closing_journals = closing_journals.where(journalized_id: project_issues.pluck(:id), journalized_type: 'Issue')
              elsif include_subprojects
                # Get all issues from the project and its subprojects
                project_ids = project.self_and_descendants.pluck(:id)
                closing_journals = closing_journals.joins(:issue).where(issues: { project_id: project_ids })
              else
                # Just the current project
                closing_journals = closing_journals.joins(:issue).where(issues: { project_id: project.id })
              end
            end
            
            # Count those where closing date is before due date
            count = 0
            closing_journals.each do |journal|
              issue = journal.journalized
              if issue && issue.due_date && journal.created_on.to_date <= issue.due_date
                count += 1
              end
            end
            
            count
          end
          
          # Average resolution time for issues created by the user
          def average_resolution_time(project=nil, options={})
            from = options[:from] || (Date.today - 12.months)
            to = options[:to] || Date.today
            
            # Extract the nested options
            include_subprojects = options[:include_subprojects].nil? ? true : options[:include_subprojects]
            include_parent_issues = options[:include_parent_issues].nil? ? true : options[:include_parent_issues]
            
            # Get resolved or closed issues created by this user
            base_query = Issue.by_author(id).resolved_or_closed.where('issues.updated_on BETWEEN ? AND ?', from, to)
            
            if project
              if include_subprojects && include_parent_issues
                # Get all project issues including related ones
                project_issues = project.all_issues_with_subprojects_and_relations(options)
                base_query = base_query.where(id: project_issues.pluck(:id))
              elsif include_subprojects
                # Get all issues from the project and its subprojects
                project_ids = project.self_and_descendants.pluck(:id)
                base_query = base_query.where(project_id: project_ids)
              else
                # Just the current project
                base_query = base_query.where(project_id: project.id)
              end
            end
            
            # Calculate average resolution time
            resolution_times = base_query.map(&:resolution_time).compact
            resolution_times.any? ? (resolution_times.sum / resolution_times.size) : 0
          end
          
          # Calculate overall contribution score
          def contribution_score(project=nil, options={})
            created = issues_created_count(project, options)
            updated = updates_count(project, options)
            closed = closed_issues_count(project, options)
            comments = comments_count(project, options)
            updates = status_updates_count(project, options)
            on_time = on_time_resolutions_count(project, options)
            
            # Get all closed issues by the user
            from = options[:from] || (Date.today - 12.months)
            to = options[:to] || Date.today
            
            # Get all closed issues to determine not-on-time resolutions
            include_subprojects = options[:include_subprojects].nil? ? true : options[:include_subprojects]
            include_parent_issues = options[:include_parent_issues].nil? ? true : options[:include_parent_issues]
            
            # Find issues closed by this user through journal entries
            closing_journals = Journal.joins(:details).where(user_id: id)
              .where("journal_details.property = 'attr' AND journal_details.prop_key = 'status_id'")
              .where("journal_details.value IN (?)", IssueStatus.where(is_closed: true).pluck(:id).map(&:to_s))
              .where('journals.created_on BETWEEN ? AND ?', from, to)
              
            if project
              if include_subprojects && include_parent_issues
                # Get all project issues including related ones
                project_issues = project.all_issues_with_subprojects_and_relations(options)
                closing_journals = closing_journals.where(journalized_id: project_issues.pluck(:id), journalized_type: 'Issue')
              elsif include_subprojects
                # Get all issues from the project and its subprojects
                project_ids = project.self_and_descendants.pluck(:id)
                closing_journals = closing_journals.joins(:issue).where(issues: { project_id: project_ids })
              else
                # Just the current project
                closing_journals = closing_journals.joins(:issue).where(issues: { project_id: project.id })
              end
            end
            
            # Count total closures
            total_closures = closing_journals.select("DISTINCT journalized_id").count
            
            # Calculate not-on-time resolutions (total closures minus on-time closures)
            not_on_time = total_closures - on_time
            
            # Administrative score (issues created, updated, closed, comments, status changes)
            admin_score = created + updated + closed + comments + updates
            
            # Technical score (weighted sum of on-time and not-on-time resolutions)
            tech_score = (on_time * 3) + not_on_time
            
            # Total score
            admin_score + tech_score
          end
          
          # Get detailed breakdown of contribution
          def contribution_details(project=nil, options={})
            created = issues_created_count(project, options)
            updated = updates_count(project, options)
            closed = closed_issues_count(project, options)
            comments = comments_count(project, options)
            updates = status_updates_count(project, options)
            on_time = on_time_resolutions_count(project, options)
            
            # Get all closed issues to determine not-on-time resolutions
            from = options[:from] || (Date.today - 12.months)
            to = options[:to] || Date.today
            include_subprojects = options[:include_subprojects].nil? ? true : options[:include_subprojects]
            include_parent_issues = options[:include_parent_issues].nil? ? true : options[:include_parent_issues]
            
            # Find issues closed by this user through journal entries
            closing_journals = Journal.joins(:details).where(user_id: id)
              .where("journal_details.property = 'attr' AND journal_details.prop_key = 'status_id'")
              .where("journal_details.value IN (?)", IssueStatus.where(is_closed: true).pluck(:id).map(&:to_s))
              .where('journals.created_on BETWEEN ? AND ?', from, to)
              
            if project
              if include_subprojects && include_parent_issues
                # Get all project issues including related ones
                project_issues = project.all_issues_with_subprojects_and_relations(options)
                closing_journals = closing_journals.where(journalized_id: project_issues.pluck(:id), journalized_type: 'Issue')
              elsif include_subprojects
                # Get all issues from the project and its subprojects
                project_ids = project.self_and_descendants.pluck(:id)
                closing_journals = closing_journals.joins(:issue).where(issues: { project_id: project_ids })
              else
                # Just the current project
                closing_journals = closing_journals.joins(:issue).where(issues: { project_id: project.id })
              end
            end
            
            # Count total closures
            total_closures = closing_journals.select("DISTINCT journalized_id").count
            not_on_time = total_closures - on_time
            
            # Calculate administrative and technical components
            admin_weight = 1.0
            admin_value = created + updated + closed + comments + updates
            
            # Technical components with weights
            on_time_weight = 3.0
            not_on_time_weight = 1.0
            tech_value = (on_time * on_time_weight) + (not_on_time * not_on_time_weight)
            
            # Calculate the total score
            total_score = (admin_value + tech_value).round(1)
            
            {
              components: {
                administrative: {
                  value: admin_value.round(1),
                  count: admin_value,
                  weight: admin_weight,
                  breakdown: {
                    created: created,
                    updated: updated,
                    closed: closed,
                    comments: comments,
                    status_updates: updates
                  }
                },
                technical: {
                  value: tech_value.round(1),
                  count: on_time + not_on_time,
                  weight: 1.0,
                  breakdown: {
                    on_time: {
                      count: on_time,
                      weight: on_time_weight
                    },
                    not_on_time: {
                      count: not_on_time,
                      weight: not_on_time_weight
                    }
                  }
                }
              },
              total: total_score
            }
          end
        end
      end
    end
  end
end

unless User.included_modules.include?(RedmineStats::Patches::UserPatch)
  User.send(:include, RedmineStats::Patches::UserPatch)
end 