class ApplicationController < Sinatra::Base

  if ENV.fetch("RACK_ENV") == "development"
    p "you're in #{__FILE__}"
  end

  # set folder for templates to ../views, but make the path absolute
  # set :views, File.expand_path('../../views', __FILE__)

  # don't enable logging when running tests
  configure :production, :development do
    enable :logging
  end

  # will be used to display 404 error pages
  not_found do
    erb :not_found
  end
end
