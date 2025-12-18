var TimeAnalytics = TimeAnalytics || {};

// Chart instance tracking
TimeAnalytics.chartInstances = {};

// Initialize all charts on the page
TimeAnalytics.initCharts = function() {
  var chartElements = document.querySelectorAll('.chart[data-chart]');
  
  chartElements.forEach(function(element) {
    try {
      // Destroy existing chart if it exists
      if (TimeAnalytics.chartInstances[element.id]) {
        TimeAnalytics.chartInstances[element.id].destroy();
      }
      
      var chartConfig = JSON.parse(element.getAttribute('data-chart'));
      
      // Ensure responsive configuration
      if (!chartConfig.options) {
        chartConfig.options = {};
      }
      chartConfig.options.responsive = true;
      chartConfig.options.maintainAspectRatio = false;
      
      // Add default tooltip formatting for time data
      if (!chartConfig.options.plugins) {
        chartConfig.options.plugins = {};
      }
      
      if (!chartConfig.options.plugins.tooltip) {
        chartConfig.options.plugins.tooltip = {
          callbacks: {
            label: function(context) {
              var label = context.dataset.label || '';
              if (label) {
                label += ': ';
              }
              
              var value = context.parsed.y !== null ? context.parsed.y : context.parsed;
              
              // Format hours with 2 decimal places
              if (typeof value === 'number') {
                label += value.toFixed(2) + 'h';
              } else {
                label += value;
              }
              
              return label;
            }
          }
        };
      }
      
      // Configure pie charts with percentage in legend
      if (chartConfig.type === 'pie') {
        var total = chartConfig.options.total_hours || chartConfig.data.datasets[0].data.reduce(function(sum, val) { return sum + val; }, 0);
        
        // Modify labels to include percentage and hours in legend
        var originalLabels = chartConfig.data.labels.slice();
        var modifiedLabels = [];
        
        for (var i = 0; i < originalLabels.length; i++) {
          var value = chartConfig.data.datasets[0].data[i];
          var percentage = total > 0 ? ((value / total) * 100).toFixed(1) : 0;
          var hours = value.toFixed(1);
          
          // Format: "Development (68.9%, 31.1h)"
          var labelWithInfo = originalLabels[i] + ' (' + percentage + '%, ' + hours + 'h)';
          modifiedLabels.push(labelWithInfo);
        }
        
        // Update chart labels
        chartConfig.data.labels = modifiedLabels;
        
        // Enhanced tooltip for pie charts
        chartConfig.options.plugins.tooltip = {
          callbacks: {
            label: function(context) {
              var label = context.label || '';
              var value = context.parsed;
              var percentage = total > 0 ? ((value / total) * 100).toFixed(1) : 0;
              // Extract original label (before parentheses) for cleaner tooltip
              var originalLabel = label.split(' (')[0];
              return originalLabel + ': ' + value.toFixed(1) + 'h (' + percentage + '%)';
            }
          }
        };
      }
      
      // Create new chart instance
      var chart = new Chart(element, chartConfig);
      
      // Store chart instance for later reference
      if (element.id) {
        TimeAnalytics.chartInstances[element.id] = chart;
        
        // Special handling for main time chart
        if (element.id === 'time-chart') {
          window.timeAnalyticsChart = chart;
        }
      }
      
    } catch (e) {
      console.error('Error initializing chart:', e);
      element.innerHTML = '<div class="error-message">Error loading chart: ' + e.message + '</div>';
    }
  });
};

// Update chart with new data
TimeAnalytics.updateChart = function(elementId, newConfig) {
  var element = document.getElementById(elementId);
  if (!element) return;
  
  // Destroy existing chart
  if (TimeAnalytics.chartInstances[elementId]) {
    TimeAnalytics.chartInstances[elementId].destroy();
    delete TimeAnalytics.chartInstances[elementId];
  }
  
  // Update data attribute
  element.setAttribute('data-chart', JSON.stringify(newConfig));
  
  // Reinitialize chart
  TimeAnalytics.initCharts();
};

// Export chart as image
TimeAnalytics.exportChart = function(chartId, filename) {
  var chart = TimeAnalytics.chartInstances[chartId];
  if (!chart) return;
  
  var canvas = chart.canvas;
  var url = canvas.toDataURL('image/png');
  
  var link = document.createElement('a');
  link.href = url;
  link.download = filename || 'chart.png';
  link.click();
};

// Resize all charts (useful for responsive layouts)
TimeAnalytics.resizeCharts = function() {
  Object.keys(TimeAnalytics.chartInstances).forEach(function(chartId) {
    TimeAnalytics.chartInstances[chartId].resize();
  });
};

// Chart color schemes
TimeAnalytics.colorSchemes = {
  default: [
    '#FF6384', '#36A2EB', '#FFCE56', '#4BC0C0', '#9966FF',
    '#FF9F40', '#8AC249', '#EA5F89', '#00D1B2', '#958AF7'
  ],
  blue: ['#E3F2FD', '#BBDEFB', '#90CAF9', '#64B5F6', '#42A5F5', '#2196F3', '#1E88E5', '#1976D2', '#1565C0', '#0D47A1'],
  green: ['#E8F5E8', '#C8E6C9', '#A5D6A7', '#81C784', '#66BB6A', '#4CAF50', '#43A047', '#388E3C', '#2E7D32', '#1B5E20'],
  warm: ['#FFF3E0', '#FFE0B2', '#FFCC80', '#FFB74D', '#FFA726', '#FF9800', '#FB8C00', '#F57C00', '#EF6C00', '#E65100']
};

// Apply color scheme to chart config
TimeAnalytics.applyColorScheme = function(chartConfig, schemeName) {
  var colors = TimeAnalytics.colorSchemes[schemeName] || TimeAnalytics.colorSchemes.default;
  
  if (chartConfig.data && chartConfig.data.datasets) {
    chartConfig.data.datasets.forEach(function(dataset, index) {
      if (chartConfig.type === 'pie' || chartConfig.type === 'doughnut') {
        dataset.backgroundColor = colors.slice(0, dataset.data.length);
      } else {
        dataset.backgroundColor = colors[index % colors.length];
        dataset.borderColor = colors[index % colors.length];
      }
    });
  }
  
  return chartConfig;
};

// Utility function to format hours
TimeAnalytics.formatHours = function(hours) {
  if (typeof hours !== 'number') return '0.00h';
  return hours.toFixed(2) + 'h';
};

// Initialize when DOM is ready
document.addEventListener('DOMContentLoaded', function() {
  // Initialize charts if they exist
  if (document.querySelectorAll('.chart[data-chart]').length > 0) {
    TimeAnalytics.initCharts();
  }
  
  // Handle window resize
  window.addEventListener('resize', function() {
    setTimeout(function() {
      TimeAnalytics.resizeCharts();
    }, 100);
  });
});

// Export for global access
window.TimeAnalytics = TimeAnalytics;