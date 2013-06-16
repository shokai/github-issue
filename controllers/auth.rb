require 'httparty'
require 'digest/md5'
require 'hashie'
require 'uri'

def user_info(session_id=nil)
  id = session_id || session[:id]
  return nil unless id
  u = Cache["auth"].get id
  return nil unless u
  Hashie::Mash.new u
end


helpers do
  def create_session_id
    Digest::MD5.hexdigest "#{rand} #{Time.now.to_i} #{Time.now.usec}"
  end

  def logout
    return unless session[:id]
    Cache["auth"].delete session[:id]
    session[:id] = nil
  end
end

get '/logout' do
  logout
  redirect '/'
end

get '/auth' do
  logout
  state = create_session_id
  Cache["auth_state"].set state, {:state => state}, {:expire => 60*60}
  query = {
    :client_id => ENV["GITHUB_APP_ID"],
    :redirect_uri => "#{app_root}/auth.callback",
    :scope => "repo,user",
    :state => state
  }.map{|k,v|
    "#{k}=#{::URI.encode v}"
  }.join("&")
  redirect "https://github.com/login/oauth/authorize?#{query}"
end

get '/auth.callback' do
  code = params["code"]
  error_and_back "bad request (code)" if code.to_s.empty?
  state = params["state"]
  if state.to_s.empty? or !Cache["auth_state"].get state
    error_and_back "bad request (state)"
  end
  Cache["auth_state"].delete state
  query = {
    :body => {
      :client_id => ENV["GITHUB_APP_ID"],
      :client_secret => ENV["GITHUB_APP_SECRET"],
      :code => code
    },
    :headers => {
      "Accept" => "application/json"
    }
  }
  res = HTTParty.post("https://github.com/login/oauth/access_token", query)
  error_and_back "github auth error" unless res.code == 200
  begin
    token = JSON.parse(res.body)["access_token"]
    client = Octokit::Client.new :oauth_token => token
    user = client.user
  rescue => e
    error_and_back "github auth error"
  end
  session_id = create_session_id
  Cache["auth"].set session_id, {
    :oauth_token => token,
    :name => user.login,
    :id => user.id,
    :icon => user.avatar_url
  }
  session[:id] = session_id
  redirect '/'
end
