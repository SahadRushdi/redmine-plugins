module RedmineStats
  module Utils
    class ChartHelper
      # Generate data for a pie chart
      def self.generate_pie_chart_data(data_hash, options={})
        # Handle empty data or nil
        return empty_chart_data('pie', options) if data_hash.nil? || data_hash.empty?
        
        # Convert all keys to strings to prevent [object Object] labels
        string_labels = data_hash.keys.map(&:to_s)
        
        chart_data = {
          labels: string_labels,
          datasets: [{
            data: data_hash.values,
            backgroundColor: generate_colors(data_hash.size),
            borderWidth: 1,
            borderColor: '#fff'
          }]
        }
        
        chart_options = {
          title: {
            display: options[:title].present?,
            text: options[:title].to_s,
            fontSize: 16
          },
          legend: {
            position: options[:legend_position] || 'right',
            labels: {
              padding: 15,
              boxWidth: 12
            }
          },
          plugins: {
            tooltip: {
              callbacks: {
                label: lambda do |tooltipItem|
                  value = data_hash.values[tooltipItem[:dataIndex]]
                  label = string_labels[tooltipItem[:dataIndex]]
                  total = data_hash.values.sum
                  percentage = ((value.to_f / total) * 100).round(1)
                  "#{label}: #{value} (#{percentage}%)"
                end,
                afterLabel: lambda do |tooltipItems|
                  "Includes nested projects and related issues"
                end
              }
            }
          }
        }
        
        {
          type: 'pie',
          data: chart_data,
          options: chart_options
        }
      end
      
      # Generate data for a bar chart
      def self.generate_bar_chart_data(data_hash, options={})
        # Handle empty data or nil
        return empty_chart_data('bar', options) if data_hash.nil? || data_hash.empty?
        
        # Convert all keys to strings to prevent [object Object] labels
        string_labels = data_hash.keys.map(&:to_s)
        
        # Use consistent colors or generate based on values
        background_colors = options[:use_value_colors] ? 
          data_hash.values.map { |v| get_color_by_value(v, options[:max_value]) } :
          (options[:single_color] ? Array.new(data_hash.size, options[:single_color] || generate_colors(1)[0]) : generate_colors(data_hash.size))
        
        chart_data = {
          labels: string_labels,
          datasets: [{
            label: options[:dataset_label].to_s,
            data: data_hash.values,
            backgroundColor: background_colors,
            borderWidth: 1,
            borderColor: background_colors.map { |c| darken_color(c) }
          }]
        }
        
        # Custom Y axis scaling
        y_axis_config = {
          ticks: {
            beginAtZero: true
          }
        }
        
        # Set max value if provided
        if options[:max_value]
          y_axis_config[:ticks][:max] = options[:max_value]
        end
        
        # Add suggested Y axis steps
        if options[:y_step]
          y_axis_config[:ticks][:stepSize] = options[:y_step]
        end
        
        chart_options = {
          title: {
            display: options[:title].present?,
            text: options[:title].to_s,
            fontSize: 16
          },
          legend: {
            display: options[:dataset_label].present?,
            labels: {
              boxWidth: 12
            }
          },
          scales: {
            yAxes: [y_axis_config],
            xAxes: [{
              ticks: {
                autoSkip: true,
                maxRotation: 45,
                minRotation: 45
              }
            }]
          },
          plugins: {
            tooltip: {
              callbacks: {
                title: lambda do |tooltipItems|
                  if tooltipItems.length > 0
                    return string_labels[tooltipItems[0][:dataIndex]]
                  end
                end,
                afterLabel: lambda do |tooltipItems|
                  "Includes nested projects and related issues"
                end
              }
            }
          }
        }
        
        {
          type: 'bar',
          data: chart_data,
          options: chart_options
        }
      end
      
      # Generate data for a line chart
      def self.generate_line_chart_data(data_hash, options={})
        # Handle empty data or nil
        return empty_chart_data('line', options) if data_hash.nil? || data_hash.empty?
        
        # Convert all keys to strings to prevent [object Object] labels
        string_labels = data_hash.keys.map(&:to_s)
        
        chart_data = {
          labels: string_labels,
          datasets: [{
            label: options[:dataset_label].to_s,
            data: data_hash.values,
            borderColor: options[:line_color] || '#36a2eb',
            backgroundColor: options[:fill_color] || 'rgba(54, 162, 235, 0.2)',
            fill: options[:fill].nil? ? true : options[:fill],
            tension: 0.2,
            borderWidth: 2,
            pointRadius: 3,
            pointHoverRadius: 5
          }]
        }
        
        # Add multiple datasets if provided
        if options[:datasets]
          chart_data[:datasets] = options[:datasets].map.with_index do |dataset, index|
            color = generate_colors(options[:datasets].size)[index]
            {
              label: dataset[:label].to_s,
              data: dataset[:data],
              borderColor: dataset[:color] || color,
              backgroundColor: dataset[:fill_color] || lighten_color(color, 0.7),
              fill: dataset[:fill].nil? ? true : dataset[:fill],
              tension: 0.2,
              borderWidth: 2,
              pointRadius: 3,
              pointHoverRadius: 5
            }
          end
        end
        
        # Custom Y axis scaling
        y_axis_config = {
          ticks: {
            beginAtZero: true
          }
        }
        
        # Set max value if provided
        if options[:max_value]
          y_axis_config[:ticks][:max] = options[:max_value]
        end
        
        # Set suggested Y axis steps
        if options[:y_step]
          y_axis_config[:ticks][:stepSize] = options[:y_step]
        end
        
        chart_options = {
          title: {
            display: options[:title].present?,
            text: options[:title].to_s,
            fontSize: 16
          },
          legend: {
            display: true,
            labels: {
              boxWidth: 12
            }
          },
          scales: {
            yAxes: [y_axis_config],
            xAxes: [{
              ticks: {
                autoSkip: true,
                maxRotation: 45,
                minRotation: 45
              }
            }]
          },
          plugins: {
            tooltip: {
              callbacks: {
                title: lambda do |tooltipItems|
                  if tooltipItems.length > 0
                    return string_labels[tooltipItems[0][:dataIndex]]
                  end
                end,
                afterLabel: lambda do |tooltipItem|
                  "Includes nested projects and related issues"
                end
              }
            }
          }
        }
        
        {
          type: 'line',
          data: chart_data,
          options: chart_options
        }
      end
      
      # Generate data for a radar chart (for user skills)
      def self.generate_radar_chart_data(data_hash, options={})
        # Handle empty data or nil
        return empty_chart_data('radar', options) if data_hash.nil? || data_hash.empty? || data_hash.values.all?(&:zero?)
        
        # Convert all keys to strings to prevent [object Object] labels
        string_labels = data_hash.keys.map(&:to_s)
        
        # Generate color
        color = options[:line_color] || '#36a2eb'
        
        # Compute dynamic scale based on data
        values = data_hash.values.map(&:to_f)
        max_value = values.max || 0
        # Allow caller override
        dynamic_max = options[:max_value]
        dynamic_step = options[:step]
        
        if dynamic_max.nil? || dynamic_step.nil?
          # Heuristic: round up to a "nice" max and choose step accordingly
          # For small values, ensure minimum headroom
          target_max = max_value
          if target_max <= 0
            target_max = 10
          else
            # Round up to 1/2/5 * 10^n
            magnitude = 10 ** (Math.log10(target_max).floor)
            candidates = [1, 2, 5, 10].map { |m| m * magnitude }
            target_max = candidates.find { |c| c >= max_value } || (10 * magnitude)
          end
          # Choose step: 5 ticks preferred
          tick_count = 5
          step = (target_max.to_f / tick_count).ceil
          # Adjust to round numbers (1/2/5 multiples)
          magnitude_step = 10 ** (Math.log10(step).floor)
          step_candidates = [1, 2, 5, 10].map { |m| m * magnitude_step }
          step = step_candidates.find { |c| c >= step } || (10 * magnitude_step)
          # Recompute max as step * tick_count to align grid
          target_max = step * tick_count
          dynamic_max ||= target_max
          dynamic_step ||= step
        end
        
        chart_data = {
          labels: string_labels,
          datasets: [{
            label: options[:dataset_label].to_s,
            data: data_hash.values,
            backgroundColor: lighten_color(color, 0.2),  # Less opacity for better visualization
            borderColor: color,
            borderWidth: 2,
            pointBackgroundColor: color,
            fill: true  # Explicitly set fill to true
          }]
        }
        
        # Add comparison dataset if provided
        if options[:comparison_data]
          comparison_color = options[:comparison_color] || '#ff6384'
          chart_data[:datasets] << {
            label: options[:comparison_label].to_s,
            data: options[:comparison_data].values,
            backgroundColor: lighten_color(comparison_color, 0.2),  # Less opacity
            borderColor: comparison_color,
            borderWidth: 2,
            pointBackgroundColor: comparison_color,
            fill: true  # Explicitly set fill
          }
        end
        
        chart_options = {
          title: {
            display: options[:title].present?,
            text: options[:title].to_s,
            fontSize: 16
          },
          legend: {
            display: chart_data[:datasets].size > 1 || options[:dataset_label].present?,
            position: 'top',
            labels: {
              boxWidth: 12
            }
          },
          scale: {
            ticks: {
              beginAtZero: true,
              max: dynamic_max || options[:max_value] || 20,
              stepSize: dynamic_step || options[:step] || 5
            },
            pointLabels: {
              fontSize: 12
            }
          },
          plugins: {
            tooltip: {
              callbacks: {
                label: lambda do |tooltipItem|
                  value = data_hash.values[tooltipItem[:dataIndex]]
                  label = string_labels[tooltipItem[:dataIndex]]
                  "#{tooltipItem.dataset.label}: #{value}"
                end,
                afterLabel: lambda do |tooltipItem|
                  "Includes nested projects and related issues"
                end
              }
            }
          }
        }
        
        {
          type: 'radar',
          data: chart_data,
          options: chart_options
        }
      end
      
      # Generate data for a line chart specifically for productivity trend
      def self.generate_productivity_trend_chart_data(data_hash, options={})
        # Handle empty data
        return empty_chart_data('line', options.merge(empty_message: 'Aucune donnée de productivité disponible')) if data_hash.nil? || data_hash.empty? || data_hash.values.all?(&:zero?)
        
        # Format dates better and sort chronologically
        sorted_data = data_hash.to_a.sort_by { |period, _| period.to_s }
        formatted_data = sorted_data.each_with_object({}) do |(period, score), result|
          # Format date for better display
          date_key = if period.to_s.include?(' to ')
                      period.to_s.split(' to ').last
                    else
                      period.to_s
                    end
          
          # Only keep day and month for cleaner display
          if date_key.match(/\d{4}-\d{2}-\d{2}/)
            date_obj = Date.parse(date_key) rescue nil
            date_key = date_obj ? date_obj.strftime('%d %b') : date_key
          end
          
          result[date_key] = score
        end
        
        # Add default styling
        options[:line_color] ||= '#4BC0C0'
        options[:fill_color] ||= 'rgba(75, 192, 192, 0.2)'
        
        # Use regular line chart generator with well-formatted data
        generate_line_chart_data(formatted_data, options)
      end
      
      # Create empty chart data with a message for when no data is available
      def self.empty_chart_data(chart_type, options={})
        no_data_message = options[:empty_message] || 'Aucune donnée disponible'
        
        case chart_type
        when 'radar'
          {
            type: chart_type,
            data: {
              labels: [no_data_message, '', '', ''],
              datasets: [{
                data: [0, 0, 0, 0],
                backgroundColor: 'rgba(200, 200, 200, 0.2)',
                borderColor: 'rgba(200, 200, 200, 0.6)',
                borderWidth: 1,
                pointBackgroundColor: 'rgba(200, 200, 200, 0.8)'
              }]
            },
            options: {
              title: {
                display: options[:title].present?,
                text: options[:title].to_s,
                fontSize: 16
              },
              legend: {
                display: false
              },
              scale: {
                ticks: {
                  beginAtZero: true,
                  max: 10,
                  stepSize: 2
                }
              },
              plugins: {
                tooltip: {
                  enabled: false
                }
              },
              responsive: true,
              maintainAspectRatio: false
            }
          }
        else
          {
            type: chart_type,
            data: {
              labels: [no_data_message],
              datasets: [{
                data: [1],
                backgroundColor: ['rgba(200, 200, 200, 0.2)'],
                borderColor: ['rgba(200, 200, 200, 0.6)'],
                borderWidth: 1
              }]
            },
            options: {
              title: {
                display: options[:title].present?,
                text: options[:title].to_s,
                fontSize: 16
              },
              legend: {
                display: false
              },
              plugins: {
                tooltip: {
                  enabled: false
                }
              },
              responsive: true,
              maintainAspectRatio: false
            }
          }
        end
      end
      
      # Helper to generate a set of distinct colors
      def self.generate_colors(count)
        # Predefined colors for up to 10 items
        colors = [
          '#FF6384', '#36A2EB', '#FFCE56', '#4BC0C0', '#9966FF',
          '#FF9F40', '#8AC249', '#EA5F89', '#00D1B2', '#958AF7'
        ]
        
        if count <= colors.size
          colors.take(count)
        else
          # Generate additional colors if needed
          result = colors.dup
          (count - colors.size).times do |i|
            # Generate colors in a more predictable way than random
            hue = (i * 137.5) % 360
            result << "hsl(#{hue}, 70%, 60%)"
          end
          result
        end
      end
      
      # Get color by numerical value (for heat mapping)
      def self.get_color_by_value(value, max_value=nil)
        max = max_value || 100.0
        value = [value.to_f, max].min
        ratio = value / max
        
        if ratio <= 0.25
          '#FF6384' # Red
        elsif ratio <= 0.5
          '#FF9F40' # Orange
        elsif ratio <= 0.75
          '#FFCE56' # Yellow
        else
          '#4BC0C0' # Green
        end
      end
      
      # Darken a color by percentage
      def self.darken_color(color, amount=0.2)
        # For simplicity, just return a slightly darker shade
        # In a real application, you might want to parse and adjust the color properly
        color
      end
      
      # Lighten a color by percentage
      def self.lighten_color(color, opacity=0.2)
        if color.start_with?('#')
          # Convert hex to rgba
          r = color[1..2].to_i(16)
          g = color[3..4].to_i(16)
          b = color[5..6].to_i(16)
          "rgba(#{r}, #{g}, #{b}, #{opacity})"
        elsif color.start_with?('rgb')
          # Already rgb, add opacity
          color.gsub('rgb', 'rgba').gsub(')', ", #{opacity})")
        else
          # Default case
          "rgba(100, 100, 100, #{opacity})"
        end
      end
    end
  end
end 