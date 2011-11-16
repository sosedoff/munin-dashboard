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
      halt 404, json_response('Server not found')
    end
  end
end

before do
  if request.path =~ /^\/api/
    content_type :json, :encoding => 'utf-8'
  end
end

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