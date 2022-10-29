require "net/http"
require "json"
require "open3"

$stdout.sync = true

def report_metric(name, value)
  now = Time.now.to_f

  header = {"Content-Type": "text/json", "DD-API-KEY": ENV.fetch("DD_CLIENT_API_KEY") }
  uri = URI.parse("https://api.datadoghq.com/api/v1/series")
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  request = Net::HTTP::Post.new(uri.request_uri, header)
  request.body = {
    "series": [
      {
        "host": ENV.fetch("DD_HOST"),
        "metric": "apcupsd.#{name}",
        "type": "gauge",
        "points": [
          [
            now,
            value
          ]
        ]
      }
    ]
  }.to_json

  response = http.request(request)
  puts "#{response.code}: #{response.body}"
rescue StandardError => e
  puts "Error sending metric: #{e.class}: #{e}"
end

def apcaccess_stat(statname)
  cmd = "apcaccess -p '#{statname}' -u status '#{ENV.fetch("APCUPSD_HOST")}'"

  stdout, stderr, status = Open3.capture3(cmd)

  if status.success?
    stdout.strip
  else
    puts "Error running apcaccess: #{stderr}"
  end
end

def power_draw
  nominal_power = apcaccess_stat("NOMPOWER").to_f
  load_pct = apcaccess_stat("LOADPCT").to_f / 100.0

  nominal_power * load_pct
end

STATUSES = %w[
  LOADPCT
  BCHARGE
  TIMELEFT
  TONBATT
].freeze

ONLINE_STATUS = "ONLINE".freeze

loop do
  if apcaccess_stat("STATUS") == ONLINE_STATUS
    puts "UPS Online"
    report_metric("status", 1)
  else
    puts "UPS Not Online"
    report_metric("status", 0)
  end

  STATUSES.each do |statname|
    value = apcaccess_stat(statname)
    puts "#{statname}: #{value}"
    report_metric(statname.downcase, value.to_f)
  end

  pwr = power_draw
  puts "POWERDRAW: #{pwr}"
  report_metric("powerdraw", pwr)
  sleep 60
end
