// Global chart instance
var timeAnalyticsChart = null;

function toggleCustomDateRange() {
  var filter = document.getElementById('filter').value;
  var customRange = document.getElementById('custom-date-range');
  if (filter === 'custom') {
    customRange.style.display = 'block';
  } else {
    customRange.style.display = 'none';
  }
}

function toggleVisualization() {
  var container = document.getElementById('chart-container');
  var btn = document.getElementById('toggle-chart-btn');
  
  if (container.style.display === 'none' || container.style.display === '') {
    container.style.display = 'block';
    btn.textContent = '<%= l(:button_hide_chart) %>';
    // Initialize chart if not already done
    if (!timeAnalyticsChart) {
      initChart();
    }
  } else {
    container.style.display = 'none';
    btn.textContent = '<%= l(:button_show_chart) %>';
  }
}

function initChart() {
  var chartElement = document.getElementById('time-chart');
  if (!chartElement) {
    console.log('Chart element not found');
    return;
  }

  // Prevent multiple chart creation
  if (timeAnalyticsChart) {
    timeAnalyticsChart.destroy();
  }

  try {
    var chartData = chartElement.getAttribute('data-chart');
    if (!chartData || chartData === 'null' || chartData === '') {
      console.log('No chart data available');
      return;
    }

    var config = JSON.parse(chartData);
    
    console.log('Creating new chart...');
    timeAnalyticsChart = new Chart(chartElement, config);
    console.log('Chart created successfully');
    
  } catch (error) {
    console.error('Error creating chart:', error);
    chartElement.parentElement.innerHTML = '<p style="text-align: center; color: #666; padding: 20px;">Chart data not available</p>';
  }
}

function updateChart() {
  var chartType = document.getElementById('chart_type').value;
  var currentForm = document.getElementById('time-analytics-form');
  
  var chartTypeInput = currentForm.querySelector('input[name="chart_type"]');
  if (!chartTypeInput) {
    chartTypeInput = document.createElement('input');
    chartTypeInput.type = 'hidden';
    chartTypeInput.name = 'chart_type';
    currentForm.appendChild(chartTypeInput);
  }
  chartTypeInput.value = chartType;
  
  // Use AJAX to update the chart data
  var formData = new FormData(currentForm);
  var url = currentForm.action + '?' + new URLSearchParams(formData).toString();
  
  fetch(url, {
    headers: {
      'X-Requested-With': 'XMLHttpRequest'
    }
  })
  .then(response => response.json())
  .then(data => {
    var chartElement = document.getElementById('time-chart');
    chartElement.setAttribute('data-chart', JSON.stringify(data.chart_data));
    initChart();
  })
  .catch(error => {
    console.error('Error updating chart:', error);
  });
}

document.addEventListener('DOMContentLoaded', function() {
  toggleCustomDateRange();
  initChart();

  var toggleBtn = document.getElementById('toggle-filters-btn');
  var collapsibleSection = document.getElementById('collapsible-filters');

  if (toggleBtn && collapsibleSection) {
    toggleBtn.addEventListener('click', function(event) {
      event.stopPropagation();
      var isOpen = collapsibleSection.classList.toggle('open');
      toggleBtn.classList.toggle('active', isOpen);
    });
  }

  document.addEventListener('click', function(event) {
    if (collapsibleSection.classList.contains('open') && !collapsibleSection.contains(event.target) && !toggleBtn.contains(event.target)) {
      collapsibleSection.classList.remove('open');
      toggleBtn.classList.remove('active');
    }
  });
});