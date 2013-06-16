io = Sinatra::RocketIO

io.on :connect do |client|
  $logger.info "new client <#{client}>"
end

io.on :disconnect do |client|
  $logger.info "leave client <#{client}>"
end

io.on :reload_issues do |data, client|
  return unless user = user_info(data["session_id"])
  if repos = Cache["issues"].get(user.name)
    $logger.info "clear #{user.name}'s issues cache"
    Cache["issues"].delete user.name
    io.emit :get_issues, data, client
  end
end

io.on :get_issues do |data, client|
  return unless user = user_info(data["session_id"])
  if repos = Cache["issues"].get(user.name)
    repos.each do |repo|
      io.push :issue, repo, :to => client.session
    end
  else
    EM::defer do
      begin
        client_ = Octokit::Client.new(:oauth_token => user.oauth_token)
        user_ = client_.user
        pages = (user_.public_repos + user_.total_private_repos)/100 + 1
        repos = []
        1.upto(pages).each{|page|
          $logger.info "reading #{user.name}'s page #{page}.."
          io.push :status, "reading page #{page}/#{pages}..", :to => client.session
          client_.repos(user.name, :per_page => 100, :page => page).each{|repo|
            next if repo.open_issues_count < 1
            next if Time.parse(repo.updated_at) < Time.now - 60*60*24*60
            repo_ = {
              :name => repo.full_name,
              :url => repo.html_url,
              :description => repo.description,
              :updated_at => Time.parse(repo.updated_at).to_i,
              :issues => client_.issues(repo.full_name).map{|i| {:number => i.number, :title => i.title} }
            }
            repos << repo_
            io.push :issue, repo_, :to => client.session
          }
        }
        io.push :status, "success", :to => client.session
        Cache["issues"].set user.name, repos, :expire => 3600*6
      rescue => e
        STDERR.puts e
        io.push :github_error, e
      end
    end
  end
end

get '/' do
  @user = user_info
  haml :index
end

get '/style.css' do
  scss :style
end
