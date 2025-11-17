class StatsReportConfig < ActiveRecord::Base
  belongs_to :project, optional: true
  belongs_to :user
  
  validates :name, presence: true
  validates :user_id, presence: true
  
  serialize :configuration, coder: JSON
  
  scope :public_configs, -> { where(is_public: true) }
  scope :for_project, ->(project_id) { where(project_id: project_id) }
  scope :global, -> { where(project_id: nil) }
  
  # Find available configs for a user in a project
  def self.available_for(user, project=nil)
    return none unless user
    
    conditions = []
    conditions << "user_id = #{user.id} OR is_public = #{connection.quoted_true}"
    
    if project
      conditions << "(project_id = #{project.id} OR project_id IS NULL)"
      where(conditions.join(' AND '))
    else
      where(conditions.join(' AND ')).global
    end
  end
  
  # Get configuration with defaults
  def config_with_defaults
    defaults = {
      'period' => 'month',
      'chart_types' => ['pie', 'bar', 'line'],
      'metrics' => ['issues_created', 'issues_closed', 'user_activity']
    }
    
    defaults.merge(configuration || {})
  end
end 