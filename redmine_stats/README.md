# Redmine Stats Plugin

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Redmine Compatibility](https://img.shields.io/badge/Redmine-6.0.x+-green.svg)](https://www.redmine.org/)

## Overview

Redmine Stats is a comprehensive statistics and analytics plugin for Redmine that provides detailed insights into project health, user contributions, and issue metrics. The plugin offers visual charts and detailed reports to help project managers and team members track performance and progress.

## Features

- **Project Health Dashboard**: Overview of project health with composite score based on resolution rates, overdue issues, and resolution time
- **User Contribution Analysis**: Track and compare user contributions with detailed breakdowns
- **Issue Statistics**: Analyze issues by status, priority, tracker, and resolution time
- **Time-based Reports**: View project trends over time with customizable date ranges
- **Nested Project Support**: Include data from subprojects in your statistics
- **Related Issues**: Track parent-child issue relationships for comprehensive reporting
- **Interactive Charts**: Visual representations of all metrics powered by Chart.js

## Screenshots

![Project Dashboard](screenshots/dashboard.png)
![User Contributions](screenshots/user_contributions.png)
![Issue Analysis](screenshots/issue_analysis.png)

## Installation

1. Clone the repository into your Redmine plugins directory:
   ```
   cd path/to/redmine/plugins
   git clone https://github.com/aouaiti/redmine_stats.git
   ```

2. Install dependencies (if any):
   ```
   bundle install
   ```

3. Run migrations:
   ```
   bundle exec rake redmine:plugins:migrate RAILS_ENV=production
   ```

4. Restart your Redmine instance.

## Usage

1. Go to the project where you want to view statistics
2. Click on the "Stats" tab in the project menu
3. Navigate between different report types:
   - Overview: General project health metrics
   - User Reports: User contribution analysis
   - Project Reports: Detailed project metrics
   - Issue Reports: Issue analysis and resolution time reports

### Date Range Filtering

All reports support filtering by date range, allowing you to analyze performance over specific time periods.

### Nested Projects and Related Issues

The plugin can include data from subprojects and related issues in the statistics. Use the checkboxes in the filter controls to customize what data is included.

## Configuration

The plugin can be configured through the Redmine administration interface:

1. Go to Administration > Plugins
2. Find "Redmine Stats Plugin" and click "Configure"
3. Adjust settings as needed:
   - Chart theme
   - Default time period
   - Date format
   - Display options

## For Developers

The plugin is structured with a modular design that can be extended for custom metrics:

- **Controllers**: `app/controllers/stats_controller.rb`
- **Models**: Various model patches in `lib/redmine_stats/patches/`
- **Views**: `app/views/stats/`
- **Utilities**: `lib/redmine_stats/utils/`

## Requirements

- Redmine 6.0.0 or higher

## Author

- **AOUAITI Ahmed**
- GitHub: [https://github.com/aouaiti](https://github.com/aouaiti)
- Repository: [https://github.com/aouaiti/redmine_stats](https://github.com/aouaiti/redmine_stats)

## License

This plugin is licensed under the MIT License.

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -am 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Create a new Pull Request 