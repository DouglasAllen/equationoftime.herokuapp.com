# environment.rb
#

require 'find'
require 'logger'
require 'uri'
require 'yaml'

# Require gems we care about
require 'rubygems'

# Set up gems listed in the Gemfile.
# See: http://gembundler.com/bundler_setup.html
#      http://stackoverflow.com/questions/7243486/why-do-you-need-require-bundler-setup
# ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../../Gemfile', __FILE__)
# require 'bundler/setup' if File.exists?(ENV['BUNDLE_GEMFILE'])
#Bundler.setup

Bundler.require(:default)

# This will load your environment variables from .env when your apps starts
# Dotenv.load  

APP_ROOT = Pathname.new(File.expand_path('../../', __FILE__))

if development?
  Bundler.require(:development)
  #require "sinatra/reloader"
  set :environment, ENV["RACK_ENV"].to_sym || :development
  configure do
    use BetterErrors::Middleware    
    BetterErrors.application_root = __dir__
  end
  #configure do
  #  Sinatra::Application.reset!
  #  use Rack::Reloader
  #end  
  #disable :run # uncomment to use irb see below.
end



# By default, Sinatra assumes that the root is the file that calls the configure block.
# Since this is not the case for us, we set it manually.
set :root, APP_ROOT.to_path
set :public_dir, File.join(APP_ROOT, 'public')
set :views, File.join(APP_ROOT, 'app', 'views')

#enable :static, :logging, :dump_errors
#disable :sessions, :run
#set :raise_errors, Proc.new { settings.environment == :development }
#set :show_exceptions, Proc.new {settings.environment == :development }

APP_NAME = APP_ROOT.basename.to_s

require APP_ROOT.join('config', 'application')

require 'irb'
#IRB.start # uncomment to use irb
