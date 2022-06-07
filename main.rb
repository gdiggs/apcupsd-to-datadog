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

def apcacces_stat(statname)
  cmd = "apcaccess -p '#{statname}' -u status '#{ENV.fetch("APCUPSD_HOST")}'"

  stdout, stderr, status = Open3.capture3(cmd)

  if status.success?
    stdout
  else
    puts "Error running apcaccess: #{stderr}"
  end
end

STATUSES = %w[
  LOADPCT
  BCHARGE
  TIMELEFT
  TONBATT
].freeze

ONLINE_STATUS = "ONLINE".freeze

loop do
  if apcacces_stat("STATUS") == ONLINE_STATUS
    puts "UPS Online"
    report_metric("status", 1)
  else
    puts "UPS Not Online"
    report_metric("status", 0)
  end

  STATUSES.each do |statname|
    value = apcacces_stat(statname)
    puts "#{statname}: #{value}"
    report_metric(statname.downcase, value.to_f)
  end
  sleep 60
end