if ENV.fetch("RACK_ENV") == "development"
  p "you're in #{__FILE__}"
end

require 'find'
require 'irb'
require 'logger'
require 'uri'
require 'yaml'

# Set up gems listed in the Gemfile.
# See: http://gembundler.com/bundler_setup.html
#      http://stackoverflow.com/questions/7243486/why-do-you-need-require-bundler-setup

ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../../Gemfile', __FILE__)
#require 'bundler/setup' if File.exists?(ENV['BUNDLE_GEMFILE'])
#require 'bundler/setup' # Set up gems listed in the Gemfile.

require 'bundler'
Bundler.require(:default)
require 'active_record'
require 'active_support'
require 'sinatra/base'
#require 'tilt/haml'
#require 'tilt/redcarpet'
