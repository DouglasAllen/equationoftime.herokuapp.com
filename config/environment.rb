# environment.rb
#

require 'find'
# Require gems we care about
require 'rubygems'

# Set up gems listed in the Gemfile.
# See: http://gembundler.com/bundler_setup.html
#      http://stackoverflow.com/questions/7243486/why-do-you-need-require-bundler-setup
# ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../../Gemfile', __FILE__)
# require 'bundler/setup' if File.exists?(ENV['BUNDLE_GEMFILE'])
#Bundler.setup

Bundler.require(:default)

if development?
  #configure do
  #  Sinatra::Application.reset!
  #  use Rack::Reloader
  #end
  #require 'awesome_print'
  # This will load your environment variables from .env when your apps starts
  #require 'dotenv'
  #Dotenv.load
  #require 'faker'
  #require 'guard'
  require 'pry-byebug'
  require "sinatra/reloader"
  #require 'sqlite3'  
  #require 'terminal-notifier-guard'
  
  #disable :run
end

# Some helper constants for path-centric logic
APP_ROOT = Pathname.new(File.expand_path('../../', __FILE__))

APP_NAME = APP_ROOT.basename.to_s

require APP_ROOT.join('config', 'application')

require 'irb'
#IRB.start
