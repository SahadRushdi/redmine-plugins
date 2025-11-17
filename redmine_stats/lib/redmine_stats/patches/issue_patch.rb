module RedmineStats
  module Patches
    module IssuePatch
      def self.included(base)
        base.class_eval do
          # Add associations if needed

          # Add scopes to help with statistics
          scope :created_between, lambda { |from, to| 
            where('issues.created_on BETWEEN ? AND ?', from, to)
          }
          
          scope :updated_between, lambda { |from, to| 
            where('issues.updated_on BETWEEN ? AND ?', from, to)
          }
          
          # Scope for resolved issues - counts statuses marked as closed and localized names like "Resolved"/"Résolu"
          scope :resolved_or_closed, lambda {
            closed_status_ids = IssueStatus.where(is_closed: true).pluck(:id)
            # Support common localized names for resolved statuses
            keywords = %w(resolved résolu resolu solucionado solucionada solved erledigt abgeschlossen risolto risolta resolvido resolvida)
            localized_ids = IssueStatus.all.select { |s| keywords.any? { |k| s.name.to_s.downcase.include?(k) } }.map(&:id)
            where(status_id: (closed_status_ids + localized_ids).uniq)
          }
          
          # Original "closed" scope - only using statuses marked as closed in system
          scope :closed, lambda { 
            where(status_id: IssueStatus.where(is_closed: true).pluck(:id))
          }
          
          scope :closed_between, lambda { |from, to|
            resolved_or_closed.where('issues.updated_on BETWEEN ? AND ?', from, to)
          }
          
          scope :by_author, lambda { |user_id|
            where(author_id: user_id)
          }
          
          scope :by_assigned_to, lambda { |user_id|
            where(assigned_to_id: user_id)
          }
          
          # Add instance methods for stats
          def resolution_time
            return nil unless closed_or_resolved?
            # Get the timestamp when the issue was marked as closed or resolved
            
            # Get IDs of statuses that are considered "resolved" (closed or named "Resolved")
            closed_status_ids = IssueStatus.where(is_closed: true).pluck(:id).map(&:to_s)
            resolved_status = IssueStatus.find_by(name: 'Resolved')
            resolved_status_id = resolved_status.id.to_s if resolved_status
            
            status_ids = resolved_status_id ? (closed_status_ids + [resolved_status_id]) : closed_status_ids
            
            closing_journal = journals.joins(:details).where(
              "journal_details.property = 'attr' AND journal_details.prop_key = 'status_id'"
            ).where(
              "journal_details.value IN (?)", status_ids
            ).order('created_on ASC').last
            
            return nil unless closing_journal
            closing_journal.created_on - created_on
          end
          
          # Check if issue is closed or resolved (supports localized names)
          def closed_or_resolved?
            return false unless status
            return true if status.is_closed
            name = status.name.to_s.downcase
            keywords = %w(resolved résolu resolu solucionado solucionada solved erledigt abgeschlossen risolto risolta resolvido resolvida)
            keywords.any? { |k| name.include?(k) }
          end
          
          def closed?
            status.is_closed if status
          end
        end
      end
    end
  end
end

unless Issue.included_modules.include?(RedmineStats::Patches::IssuePatch)
  Issue.send(:include, RedmineStats::Patches::IssuePatch)
end 