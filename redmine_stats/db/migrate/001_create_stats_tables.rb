class CreateStatsTables < ActiveRecord::Migration[6.0]
  def change
    # Table to store custom report configurations
    create_table :stats_report_configs, id: :integer do |t|
      t.integer :project_id
      t.integer :user_id, null: false
      t.string :name, null: false, limit: 255
      t.text :description
      t.text :configuration
      t.boolean :is_public, default: false
      t.timestamps null: false
    end
    
    add_index :stats_report_configs, :project_id
    add_index :stats_report_configs, :user_id
    add_foreign_key :stats_report_configs, :projects
    add_foreign_key :stats_report_configs, :users
    
    # Table to store snapshots of statistics for historical comparison
    create_table :stats_snapshots, id: :integer do |t|
      t.integer :project_id, null: false
      t.date :snapshot_date, null: false
      t.string :snapshot_type, null: false, limit: 50
      t.text :data
      t.timestamps null: false
    end
    
    add_index :stats_snapshots, [:project_id, :snapshot_date, :snapshot_type], name: 'index_stats_snapshots_on_project_date_type'
    add_foreign_key :stats_snapshots, :projects
  end
end 