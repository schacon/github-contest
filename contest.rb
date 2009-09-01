require 'rubygems'
require 'sinatra'
require 'dm-core'
require 'dm-aggregates'
require 'open-uri'
require 'json'

## -- DATABASE STUFF --

DataMapper.setup(:default, ENV['DATABASE_URL'] || "sqlite3://#{Dir.pwd}/local.db")

class ContestEntry
  include DataMapper::Resource
  has n, :scores
  has n, :pushes
  property :id,         Serial
  property :name,       String, :key => true
  property :owner,      String
  property :email,      String
  property :description, String
  property :homepage,    String
  property :entered,    DateTime
  property :highscore,  Integer
  property :status,      String

  def nwo
    self.owner + '/' + self.name
  end
end

class Score
  include DataMapper::Resource
  belongs_to :contest_entry
  belongs_to :push
  property :id,       Serial
  property :score,    Integer
end

class Push
  include DataMapper::Resource
  has 1, :score
  belongs_to :contest_entry
  property :id,       Serial
  property :ref,      String
  property :sha,      String
  property :results_sha, String, :index => true
  property :message, String
  property :entered,  DateTime
end

DataMapper.auto_upgrade!

## -- WEBSITE STUFF --

get '/' do
  File.read('public/index.html')
end

get '/register' do
  erb :register
end

# leaderboard api
get '/leaderboard' do
  @entries = ContestEntry.all(:highscore.gt => 0, :status => 'good', :order => [:highscore.desc, :entered])
  erb :leaderboard
end

# individual project data
get '/p/:user/:repo' do
  @entry = ContestEntry.first({:name => params[:repo], :owner => params[:user]})
  if @entry
    erb :project
  else
    erb :notfound
  end
end

get '/action' do
  @entries = ContestEntry.all(:order => [:id.desc], :limit => 10)
  @scores = Score.all(:order => [:id.desc], :limit => 10)
  @pushes = Push.all(:order => [:id.desc], :limit => 25)
  erb :action
end

# post receive handler
post '/' do
  # contest over
end

