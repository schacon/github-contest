require 'rubygems'
require 'sinatra'

# post receive handler
get '/hook' do
end

# leaderboard api
get '/leaderboard' do
end

# individual project data api
get '/p/:user/:repo' do
end

get '/env' do
  ENV.inspect
end