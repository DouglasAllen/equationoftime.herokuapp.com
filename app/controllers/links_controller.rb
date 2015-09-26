#require_relative 'application_controller'

class LinksController# < ApplicationController

  if ENV.fetch("RACK_ENV") == "development"
    p "you're in #{__FILE__}"
  end

  attr_reader :wikipedia

  def initialize
    @wikipedia = lambda do
      "<a href = 'https://commons.wikimedia.org/wiki/File:Zeitgleichung.png'>link</a>"
    end
  end

end