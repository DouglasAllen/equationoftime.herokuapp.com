if ENV.fetch("RACK_ENV") == "development"
  "you're in #{__FILE__}"
end

require 'pathname'
require 'bundler'
Bundler.require(:default)
require 'sinatra/base'
require 'tilt/haml'
require 'glorify'
require 'haml'
