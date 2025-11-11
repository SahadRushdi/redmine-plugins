# frozen_string_literal: true

require 'redmine/export/pdf'

class StatusReportPdf < Redmine::Export::PDF::ITCPDF
  include Redmine::I18n
  include Redmine::Export::PDF::IssuesPdfHelper
  
  def initialize(projects, lang)
    set_language_if_valid(lang)
    super(lang, 'P')
    
    @projects = projects
    set_title('Status Report')
    alias_nb_pages
    footer_date = format_date(User.current.today)
  end
  
  def to_pdf
    add_page
    
    SetFontStyle('B', 16)
    RDMCell(190, 10, 'Status Report', 0, 1, 'C')
    ln(5)
    
    @projects.each do |project|
      SetFontStyle('B', 14)
      RDMCell(190, 8, project.name, 0, 1)
      SetFontStyle('', 10)
      
      if project.issues.any?
        project.issues.each do |issue|
          SetFontStyle('B', 10)
          RDMCell(190, 6, "##{issue.id}: #{issue.subject}", 0, 1)
          SetFontStyle('', 9)
          RDMCell(190, 5, "Status: #{issue.status.name} | Tracker: #{issue.tracker.name}", 0, 1)
          if issue.assigned_to
            RDMCell(190, 5, "Assigned to: #{issue.assigned_to.name}", 0, 1)
          end
          ln(3)
        end
      else
        SetFontStyle('I', 9)
        RDMCell(190, 5, 'No open issues', 0, 1)
      end
      
      ln(5)
    end
    
    output
  end
end
