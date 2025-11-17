class StatsSnapshot < ActiveRecord::Base
  belongs_to :project
  
  validates :project_id, presence: true
  validates :snapshot_date, presence: true
  validates :snapshot_type, presence: true
  
  serialize :data, coder: JSON
  
  TYPES = %w(project_summary user_activity issues_overview)
  
  scope :of_type, ->(type) { where(snapshot_type: type) }
  scope :for_project, ->(project_id) { where(project_id: project_id) }
  scope :recent, ->(count=5) { order(snapshot_date: :desc).limit(count) }
  scope :between_dates, ->(start_date, end_date) { where("snapshot_date BETWEEN ? AND ?", start_date, end_date) }
  
  # Create a snapshot of project statistics
  def self.create_project_summary(project, date=Date.today)
    create(
      project: project,
      snapshot_date: date,
      snapshot_type: 'project_summary',
      data: {
        open_issues: project.issues.open.count,
        closed_issues: project.issues.closed.count,
        total_issues: project.issues.count,
        health_score: RedmineStats::Utils::StatsCalculator.calculate_project_health_score(project),
        avg_resolution_time: project.average_resolution_time,
        top_contributors: project.top_contributors(5).map { |c| { name: c[:user].name, score: c[:score] } }
      }
    )
  end
  
  # Create a snapshot of user activity
  def self.create_user_activity(project, date=Date.today)
    member_ids = project.members.pluck(:user_id)
    users = User.where(id: member_ids)
    
    activity_data = users.map do |user|
      {
        user_id: user.id,
        name: user.name,
        issues_created: user.issues_created_count(project),
        issues_updated: user.updates_count(project),
        issues_closed: user.closed_issues_count(project),
        contribution_score: user.contribution_score(project)
      }
    end
    
    create(
      project: project,
      snapshot_date: date,
      snapshot_type: 'user_activity',
      data: {
        users: activity_data,
        total_users: users.count
      }
    )
  end
  
  # Create a snapshot of issues statistics
  def self.create_issues_overview(project, date=Date.today)
    create(
      project: project,
      snapshot_date: date,
      snapshot_type: 'issues_overview',
      data: {
        by_status: project.issues_by_status,
        by_priority: project.issues_by_priority,
        by_tracker: project.issues_by_tracker,
        recent_activity: project.issues_created_over_time(interval: 'day', from: (date - 30.days), to: date)
      }
    )
  end
end 