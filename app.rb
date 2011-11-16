require 'bundler/setup'
require 'sinatra'
require 'uuidtools'
require 'redis'
require 'bson'
require 'mongo'
require 'mongoid'
require 'json'
require 'munin-ruby'

if RUBY_VERSION >= '1.9'
  $LOAD_PATH << '.'
end

require 'app/models/server'
require 'app/monitor'

# ------------------------------------------------------------------------------

configure do
  Mongoid.database = Mongo::Connection.new.db('munin_dashboard')
end

helpers do
  def json_response(data)
    data.to_json
  end
  
  def find_server
    @server = Server.find_by_name(params[:name])
    if @server.nil?
      halt 404, json_response(:error => 'Server not found')
    end
  end
  
  def find_monitor
    @monitor = $monitors[@server.name]
    if @monitor.nil?
      halt 404, json_response(:error => 'Monitor for this server was not found')
    end
  end
end

before do
  if request.path =~ /^\/api/
    content_type :json, :encoding => 'utf-8'
  end
end

$monitors = {}
$redis = Redis.new

get '/' do
  erb :index
end

get '/api' do
  json_response(:time => Time.now)
end

get '/api/servers' do
  json_response(Server.all)
end

post '/api/servers' do
  server = Server.new(params[:server])
  if server.save
    json_response(server)
  else
    halt 400, json_response(:errors => server.errors)
  end
end

get '/api/servers/:name' do
  find_server
  json_response(@server)
end

put '/api/servers/:name' do
  find_server
  if @server.update_attributes(params[:server])
    json_response(@server)
  else
    halt 400, json_response(:errors => @server.errors)
  end
end

delete '/api/servers/:name' do
  find_server
  @server.destroy
  json_response(:destroyed => @server.destroyed?)
end

get '/api/monitors' do
  json_response($monitors)
end

get '/api/monitor/:name' do
  find_server
  find_monitor
  json_response(@monitor)
end

post'/api/monitor/:name' do
  find_server
  
  if $monitors.key?(@server.name)
    halt 400, json_response(:error => "already exists")
  end
  
  services = params[:services]
  period   = (params[:period] || 3).to_i
  
  unless services.kind_of?(Array)
    halt 400, json_response(:error => "services parameter required")
  end
  
  unless (1..10).include?(period)
    halt 400, json_response(:error => "period should be in [1..10] range")
  end
  
  $monitors[@server.name] = Monitor.new(@server, services, period)
  json_response($monitors[@server.name])
end

get '/api/monitor/:name/start' do
  find_server
  find_monitor
  
  if @monitor.running?
    halt 400, json_response(:error => "Monitor is already running")
  end
  
  @monitor.start
  json_response(@monitor)
end

get '/api/monitor/:name/stop' do
  find_server
  find_monitor
  
  unless @monitor.running?
    halt 400, json_response(:error => "Monitor is not running")
  end
  
  @monitor.stop
  json_response(@monitor)
end

get '/api/monitor/:name/config' do
  find_server
  find_monitor
  
  unless @monitor.running?
    halt 400, json_response(:error => "Monitor is not running")
  end
  
  $redis.hget(Monitor::KEY_CONFIG, @server.name)
end

get '/api/monitor/:name/fetch' do
  find_server
  find_monitor
  
  unless @monitor.running?
    halt 400, json_response(:error => "Monitor is not running")
  end
  
  $redis.hget(Monitor::KEY_FETCH, @server.name)
end
