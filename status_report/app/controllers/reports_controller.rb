# plugins/status_report/app/controllers/reports_controller.rb

class ReportsController < ApplicationController
  unloadable 
  before_action :require_login 

  def index
    @active_projects = Project.where(status: 1).order(:identifier)
    @active_projects.each do |project|
      project.issues = Issue.where(project_id: project.id, closed_on: nil)
                            .includes(:status, :tracker, :assigned_to)
                            .order(:status_id, :priority_id)
    end

    respond_to do |format|
      # Standard HTML request
      format.html 

      format.pdf do
        require File.expand_path('../../../lib/status_report_pdf', __FILE__)
        pdf = StatusReportPdf.new(@active_projects, Setting.default_language)

        send_data pdf.to_pdf,
                  filename: "Status_Report_#{Date.today}.pdf",
                  type: 'application/pdf',
                  disposition: 'attachment'
      end
    end
  end
end
