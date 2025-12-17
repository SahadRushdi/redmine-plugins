# Redmine Time Analytics Plugin

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Redmine Compatibility](https://img.shields.io/badge/Redmine-5.0.x+-green.svg)](https://www.redmine.org/)

## Overview

Redmine Time Analytics is a comprehensive time tracking analytics and reporting plugin for Redmine that provides detailed insights into time logging patterns, productivity metrics, and project time distribution. The plugin features an optimized side-by-side layout, interactive charts, detailed reports, and export capabilities to help users and managers track time effectively with maximum information density.

## Features

### Individual Dashboard
- **Personal Time Analytics**: View your own logged time with comprehensive filtering
- **Multiple View Modes**: Switch between Time Entries, Activity Analysis, and Grouping views
- **Multiple Time Periods**: Today, this week, this month, this year, or custom date ranges
- **Flexible Grouping**: Group data by daily, weekly, monthly, or yearly periods
- **Interactive Charts**: Bar, line, and pie charts powered by Chart.js with real-time switching
- **Optimized Layout**: Side-by-side summary and visualization for maximum screen utilization
- **Compact Statistics**: 2x2 grid layout showing total hours, entry counts, daily averages, max/min daily hours
- **Activity Analysis**: Cross-tabulation matrix showing activity distribution across time periods
- **Advanced Search**: Search across projects, issues, and comments
- **Export Functionality**: Export data and visualizations as CSV
- **Responsive Design**: Works on desktop and mobile devices with adaptive layouts

### UI/UX Improvements
- **Space-Optimized Layout**: Summary section (280px) + Visualization section (remaining space)
- **Information Density**: All key metrics visible without scrolling
- **Consistent Date Formatting**: Sunday-Saturday week format across all views
- **Collapsible Filters**: Toggle filter visibility to maximize content area
- **Mobile-First Design**: Sections stack vertically on smaller screens

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

### Getting Started
1. After installation, you'll see "Time Analytics" in the top menu
2. Click on "Time Analytics" to access the Individual Dashboard
3. Use the toggle buttons to switch between view modes:
   - **Time Entries**: Detailed list of individual time entries
   - **Activity**: Analysis grouped by activity types with cross-tabulation for weekly/monthly/yearly views
   - **Grouping**: Time data grouped by selected time period

### Dashboard Features
4. **Filter Controls**: Click the filter icon to show/hide advanced filters
   - Select time period (today, this week, this month, this year, or custom range)
   - Choose grouping (daily, weekly, monthly, yearly)
   - Search for specific projects, issues, or comments
5. **Analytics Section**: View summary statistics and interactive charts side-by-side
   - **Summary**: Compact 2x2 grid showing key metrics
   - **Visualization**: Interactive charts with real-time type switching (bar, line, pie)
6. **Data Table**: Detailed results below the analytics section with pagination
7. **Export**: Export filtered data and visualizations as CSV for further analysis

### Chart Interaction
- Use the chart type dropdown to switch between bar, line, and pie charts
- Toggle chart visibility using the "Show/Hide Chart" button
- All charts are responsive and work across different screen sizes

## Technical Details

### Architecture
- **Controllers**: `TimeAnalyticsController` handles all dashboard requests with multi-view support
- **Helpers**: `TimeAnalyticsHelper` provides view helper methods and consistent date formatting
- **Views**: Optimized ERB templates with side-by-side analytics layout
- **Chart Library**: Chart.js for interactive visualizations with real-time type switching
- **Utilities**: Modular chart generation and CSV export helpers

### UI/UX Design
The plugin implements a modern, space-optimized design:
- **Analytics Section**: Flexbox layout with summary (280px fixed) + visualization (flex-grow)
- **Responsive Breakpoints**: Desktop side-by-side, mobile stacked layout
- **Information Hierarchy**: Analytics first, detailed data second
- **Consistent Formatting**: Unified Sunday-Saturday week display across all views

### Chart Integration
Advanced Chart.js integration with custom wrapper:
- Initializes charts from HTML data attributes
- Real-time chart type switching (bar ↔ line ↔ pie)
- Responsive chart behavior with optimized dimensions
- Handles chart updates and interactions
- Supports multiple chart instances with proper cleanup

### Database Queries
- Efficiently queries TimeEntry model with proper joins and includes
- Cross-database compatibility (MySQL, PostgreSQL, SQLite)
- Supports filtering, pagination, and full-text search
- Activity pivot tables with optimized matrix generation
- Consistent date grouping logic across view modes
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

### Recent Improvements (December 2025)
- **Optimized Layout**: Implemented side-by-side analytics layout for maximum information density
- **Compact Summary**: Redesigned statistics as 2x2 grid for better space utilization
- **Chart Optimization**: Reduced chart height and margins to eliminate empty space
- **Consistent Date Logic**: Unified Sunday-Saturday week formatting across Time Entries and Activity views
- **Enhanced Responsiveness**: Improved mobile layout with proper section stacking
- **Performance**: Optimized chart rendering and reduced visual gaps

### Extending the Plugin
The plugin is designed to be extensible:
- Add new chart types by extending chart generation methods in controller
- Create new dashboard tabs by adding controller actions and views
- Extend export functionality by adding new CSV export methods
- Customize layout by modifying CSS flexbox properties in `time_analytics.css`
- Add new view modes by extending the toggle view logic

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