require_relative 'application_controller'

class ExampleController < ApplicationController

  if ENV.fetch("RACK_ENV") == "development"
    p "you're in #{__FILE__}"
  end

  get '/' do
    title "Example Page"
    erb :example
  end

end
