require 'rubygems'
require 'sinatra'
require 'dm-core'
require 'open-uri'
require 'json'

## -- DATABASE STUFF --

DataMapper.setup(:default, ENV['DATABASE_URL'] || "sqlite3://#{Dir.pwd}/local.db")

class ContestEntry
  include DataMapper::Resource 
  has n, :scores  
  property :id,         Serial
  property :name,       String, :key => true 
  property :owner,      String
  property :email,      String
  property :description, String
  property :homepage,    String
  property :entered,    DateTime
  property :highscore,  Integer
  
  def nwo
    self.owner + '/' + self.name
  end
end

class Score
  include DataMapper::Resource 
  belongs_to :contest_entry
  property :id,       Serial  
  property :ref,      String
  property :sha,      String
  property :entered,  DateTime
  property :score,    Integer
end

DataMapper.auto_upgrade!

## -- WEBSITE STUFF --

get '/' do
  File.read('public/index.html')
end

# leaderboard api
get '/leaderboard' do
  @entries = ContestEntry.all(:order => [:highscore.desc])
  erb :leaderboard
end

# individual project data
get '/p/:user/:repo' do
  @entry = ContestEntry.first({:name => :repo, :owner => :user})
  erb :project
end

get '/debug' do
  @entries = ContestEntry.all
  @scores = Score.all
  erb :debug
end

# post receive handler
post '/' do
  push = JSON.parse(params[:payload])
  
  repo      = push['repository']
  repo_name = repo['name']
  owner     = repo['owner']['name']
  after     = push['after']
  
  # get or create the entry
  entry = ContestEntry.first(:name => repo_name, :owner => owner)
  if !entry
    entry = ContestEntry.new
    entry.attributes = {:name => repo_name, :owner => owner, :entered => Time.now()}
    entry.save
    # email to congratulate for joining?
  end
  entry.homepage = repo['homepage']
  entry.description = repo['description']
  entry.email = repo['owner']['email']

  # read the results
  raw = "http://github.com/#{owner}/#{repo_name}/raw/#{after}/results.txt"
  results = open(raw) do |f|
    f.read
  end

  if results
    key = JSON.parse(File.read('key.json'))
    score = 0
    results.split("\n").each do |guess|
      (uid, rids) = guess.split(':')
      next if !key[uid]
      next if !rids
      rids = rids.split(',')
      if rids.include? key[uid]
        score += 1
      end
    end

    if score > 0
      sc = Score.new
      sc.score = score
      sc.save
      entry.scores << sc
      hs = entry.highscore || 0
      if score > hs
        entry.highscore = score
      end
      entry.save
    end

  end
end
