require 'rubygems'
require 'sinatra'

DataMapper.setup(:default, ENV['DATABASE_URL'] || 'sqlite3://my.db')

class Entry
  include DataMapper::Resource
 
  # The Serial type provides auto-incrementing primary keys
  property :id,         Serial
  # ...or pass a :key option for a user-set key like the name of a user:
  property :name,       String, :key => true
 
  property :title,      String
  property :body,       Text
  property :created_at, DateTime
end

# post receive handler
get '/hook' do
end

# leaderboard api
get '/leaderboard' do
end

# individual project data api
get '/p/:user/:repo' do
end
