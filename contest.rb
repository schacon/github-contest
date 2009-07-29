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
  has n, :pushes
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
  @entries = ContestEntry.all(:highscore.gt => 0, :order => [:highscore.desc])
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

  # save the push information
  pu = Push.new
  pu.sha = after
  pu.ref = push['ref']
  pu.entered = Time.now()
  pu.save
  entry.pushes << pu
  entry.save

  # look for a changed file
  new_results = false
  tree_url = "http://github.com/api/v2/json/tree/show/#{owner}/#{repo_name}/#{after}"
  tree = open(tree_url) do |f|
    f.read
  end

  new_tree = JSON.parse(tree)
  new_tree['tree'].each do |f|
    if f['name'] == 'results.txt'
      if !Push.first(:results_sha => f['sha'])
        new_results = true
        pu.message = 'processing new results.txt file'
      else
        pu.message = 'no new results.txt file'
      end
      pu.results_sha = f['sha']
      pu.save
    end
  end
  
  if new_results
    # read the results
    raw = "http://github.com/#{owner}/#{repo_name}/raw/#{after}/results.txt"
    results = open(raw) do |f|
      f.read
    end

    if results
      key = JSON.parse(File.read('key.json'))
      score = 0
    
      # verify that it is the right format (add to error if not)
      results.split("\n").each do |guess|
        (uid, rids) = guess.split(':')
        next if !key[uid]
        next if !rids
        rids = rids.split(',')[0, 10] # verify that each entry only has up to 10 guesses
        if rids.include? key[uid]
          key.delete uid # verify that each entry is only there once
          score += 1
        end
      end

      if score > 0
        sc = Score.new
        sc.score = score
        sc.push = pu
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
end
