# Redmine Time Analytics Plugin

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Redmine Compatibility](https://img.shields.io/badge/Redmine-5.0.x+-green.svg)](https://www.redmine.org/)

## Overview

Redmine Time Analytics is a comprehensive time tracking analytics and reporting plugin for Redmine that provides detailed insights into time logging patterns, productivity metrics, and project time distribution. The plugin offers interactive charts, detailed reports, and export capabilities to help users and managers track time effectively.

## Features

### Individual Dashboard
- **Personal Time Analytics**: View your own logged time with comprehensive filtering
- **Multiple Time Periods**: Today, this week, this month, this year, or custom date ranges
- **Flexible Grouping**: Group data by daily, weekly, monthly, or yearly periods
- **Interactive Charts**: Bar, line, and pie charts powered by Chart.js
- **Detailed Statistics**: Total hours, entry counts, daily averages, max/min daily hours
- **Advanced Search**: Search across projects, issues, and comments
- **Export Functionality**: Export data and visualizations as CSV
- **Responsive Design**: Works on desktop and mobile devices

### Coming Soon
- **Team Dashboard**: Team productivity insights and workload distribution
- **Custom Dashboard**: Personalized analytics views with configurable widgets

## Installation

1. Clone the repository into your Redmine plugins directory:
   ```bash
   cd path/to/redmine/plugins
   git clone https://github.com/your-repo/redmine_time_analytics.git
   ```

2. Install dependencies (if any):
   ```bash
   bundle install
   ```

3. Run migrations (if any):
   ```bash
   bundle exec rake redmine:plugins:migrate RAILS_ENV=production
   ```

4. Restart your Redmine instance.

## Usage

1. After installation, you'll see "Time Analytics" in the top menu
2. Click on "Time Analytics" to access the Individual Dashboard
3. Use the filters to customize your time analysis:
   - Select time period (today, this week, this month, this year, or custom range)
   - Choose grouping (daily, weekly, monthly, yearly)
   - Search for specific projects, issues, or comments
4. View your data in the results table or toggle chart visualization
5. Export your data as CSV for further analysis

## Technical Details

### Architecture
- **Controllers**: `TimeAnalyticsController` handles all dashboard requests
- **Helpers**: `TimeAnalyticsHelper` provides view helper methods
- **Chart Library**: Chart.js for interactive visualizations
- **Utilities**: Modular chart and CSV export helpers

### Chart Integration
The plugin uses Chart.js with a custom wrapper (`time_analytics_charts.js`) that:
- Initializes charts from HTML data attributes
- Provides responsive chart behavior
- Handles chart updates and interactions
- Supports multiple chart instances

### Database Queries
- Efficiently queries TimeEntry model with proper joins
- Supports filtering, pagination, and search
- Optimized for performance with large datasets

## Requirements

- Redmine 5.0.0 or higher
- Modern web browser with JavaScript enabled

## Development

### File Structure
```
redmine_time_analytics/
├── app/
│   ├── controllers/time_analytics_controller.rb
│   ├── helpers/time_analytics_helper.rb
│   └── views/time_analytics/
├── assets/
│   ├── javascripts/time_analytics_charts.js
│   └── stylesheets/time_analytics.css
├── config/
│   ├── locales/en.yml
│   └── routes.rb
├── lib/
│   └── redmine_time_analytics/
│       └── utils/
└── init.rb
```

### Extending the Plugin
The plugin is designed to be extensible:
- Add new chart types in `ChartHelper`
- Create new dashboard tabs by adding controller actions and views
- Extend export functionality in `CsvExporter`

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -am 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Create a new Pull Request

## License

This plugin is licensed under the MIT License.

## Support

For issues and feature requests, please use the GitHub issue tracker.