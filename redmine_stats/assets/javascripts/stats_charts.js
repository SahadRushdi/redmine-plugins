var RedmineStats = RedmineStats || {};

// Initialize all charts on the page
RedmineStats.initCharts = function() {
  var chartElements = document.querySelectorAll('.chart[data-chart]');
  
  chartElements.forEach(function(element) {
    try {
      var chartConfig = JSON.parse(element.getAttribute('data-chart'));
      
      // Add tooltips by default for all charts
      if (!chartConfig.options.plugins) {
        chartConfig.options.plugins = {};
      }
      
      // Enable tooltips with better formatting
      if (!chartConfig.options.plugins.tooltip) {
        chartConfig.options.plugins.tooltip = {
          callbacks: {
            label: function(context) {
              var label = context.dataset.label || '';
              if (label) {
                label += ': ';
              }
              if (context.parsed.y !== null) {
                label += context.parsed.y;
              } else if (context.parsed !== null) {
                label += context.parsed;
              }
              return label;
            }
          }
        };
      }
      
      // Add responsive option
      chartConfig.options.responsive = true;
      chartConfig.options.maintainAspectRatio = false;
      
      // Create chart
      new Chart(element, chartConfig);
    } catch (e) {
      console.error('Error initializing chart:', e);
      element.innerHTML = '<div class="alert alert-error">Error loading chart</div>';
    }
  });
};

// Initialize the gauge visualization
RedmineStats.initGauge = function() {
  var gaugeElements = document.querySelectorAll('.gauge[data-score]');
  
  gaugeElements.forEach(function(element) {
    var score = parseFloat(element.getAttribute('data-score')) || 0;
    
    // Determine color based on score
    var color;
    if (score >= 80) {
      color = '#4BC0C0'; // Green
    } else if (score >= 60) {
      color = '#FFCE56'; // Yellow
    } else if (score >= 40) {
      color = '#FF9F40'; // Orange
    } else {
      color = '#FF6384'; // Red
    }
    
    // Set gauge rotation based on score (180 degrees = 0 score, 0 degrees = 100 score)
    var rotation = 180 - (score * 1.8);
    
    // Create gauge needle
    var needle = document.createElement('div');
    needle.className = 'gauge-needle';
    needle.style.transform = 'rotate(' + rotation + 'deg)';
    element.appendChild(needle);
    
    // Apply color to gauge value
    var valueElement = element.querySelector('.gauge-value');
    if (valueElement) {
      valueElement.style.color = color;
      valueElement.innerHTML = score + '<span class="gauge-score-label">/100</span>';
    }
    
    // Create gauge color segments
    var segments = [
      { color: '#FF6384', position: 0, label: 'Poor' },   // Red
      { color: '#FF9F40', position: 25, label: 'Fair' },  // Orange
      { color: '#FFCE56', position: 50, label: 'Good' },  // Yellow
      { color: '#4BC0C0', position: 75, label: 'Excellent' }   // Green
    ];
    
    // Create gauge legend
    var legendDiv = document.createElement('div');
    legendDiv.className = 'gauge-legend';
    
    segments.forEach(function(segment, index) {
      var segmentElement = document.createElement('div');
      segmentElement.className = 'gauge-segment';
      segmentElement.style.backgroundColor = segment.color;
      segmentElement.style.left = segment.position + '%';
      segmentElement.style.width = '25%';
      element.insertBefore(segmentElement, element.firstChild);
      
      // Add label to the legend
      var legendItem = document.createElement('div');
      legendItem.className = 'gauge-legend-item';
      legendItem.innerHTML = 
        '<span class="color-dot" style="background-color:' + segment.color + '"></span>' +
        '<span class="legend-label">' + segment.label + ' (' + segment.position + '-' + (segment.position + 25) + ')</span>';
      legendDiv.appendChild(legendItem);
    });
    
    // Insert the legend after the gauge
    element.parentNode.insertBefore(legendDiv, element.nextSibling);
  });
  
  // Add tooltip to score
  var scoreInfoElements = document.querySelectorAll('.health-score-info');
  scoreInfoElements.forEach(function(element) {
    element.addEventListener('click', function(e) {
      e.preventDefault();
      
      // Get the tooltip - check if it's a health or contribution tooltip
      var tooltipId;
      if (element.title.includes('health')) {
        tooltipId = 'health-score-tooltip';
      } else if (element.title.includes('contribution')) {
        tooltipId = 'contribution-score-tooltip';
      }
      
      var tooltip = document.getElementById(tooltipId);
      
      if (tooltip) {
        // Position the tooltip near the info icon
        var rect = element.getBoundingClientRect();
        tooltip.style.top = (rect.bottom + window.scrollY + 5) + 'px';
        tooltip.style.left = (rect.left + window.scrollX - 150) + 'px'; // Center tooltip
        
        // Toggle display
        tooltip.style.display = tooltip.style.display === 'block' ? 'none' : 'block';
        
        // Hide when clicking elsewhere
        var hideTooltip = function() {
          tooltip.style.display = 'none';
          document.removeEventListener('click', hideTooltipOnOutsideClick);
        };
        
        var hideTooltipOnOutsideClick = function(event) {
          if (!tooltip.contains(event.target) && event.target !== element) {
            hideTooltip();
          }
        };
        
        // Add timeout to allow immediate clicks to register
        setTimeout(function() {
          document.addEventListener('click', hideTooltipOnOutsideClick);
        }, 10);
      }
    });
  });
};

// Export functionality for reports
RedmineStats.exportToCsv = function(tableId, filename) {
  var table = document.getElementById(tableId);
  if (!table) return;
  
  var rows = table.querySelectorAll('tr');
  var csv = [];
  
  for (var i = 0; i < rows.length; i++) {
    var row = [], cols = rows[i].querySelectorAll('td, th');
    
    for (var j = 0; j < cols.length; j++) {
      // Get text content and escape double quotes
      var data = cols[j].textContent.replace(/"/g, '""');
      row.push('"' + data + '"');
    }
    
    csv.push(row.join(','));
  }
  
  var csvString = csv.join('\n');
  var downloadLink = document.createElement('a');
  downloadLink.href = 'data:text/csv;charset=utf-8,' + encodeURIComponent(csvString);
  downloadLink.download = filename || 'export.csv';
  downloadLink.style.display = 'none';
  document.body.appendChild(downloadLink);
  downloadLink.click();
  document.body.removeChild(downloadLink);
}; 