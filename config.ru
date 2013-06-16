require 'rubygems'
require 'bundler/setup'
require 'rack'
require 'sinatra'
require 'logger'
$logger = Logger.new $stdout
if development?
  $stdout.sync = true
  $logger.level = Logger::INFO
  require 'sinatra/reloader'
elsif production?
  $logger.level = Logger::WARN
end

require 'sinatra/rocketio'
require 'sinatra/content_for'
require 'haml'
require 'sass'
require 'json'
require 'hashie'
require 'octokit'
$:.unshift File.dirname(__FILE__)
require 'libs/cache'
require 'helpers/helper'
require 'controllers/auth'
require 'controllers/main'

set :haml, :escape_html => true
enable :sessions
set :session_secret, (ENV["SESSION_SECRET"] || "this is a default session secret")

run Sinatra::Application
