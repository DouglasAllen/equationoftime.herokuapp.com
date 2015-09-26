#require_relative '../controllers/application_controller'

class MenuController# < ApplicationController

  if ENV.fetch("RACK_ENV") == "development"
    p "you're in #{__FILE__}"
  end

  def home;lambda { haml :home };end

  def tutorial;lambda { haml :tutorial };end  

  def data;lambda {haml :analemma};end

  def eot;lambda {haml :eot};end

  def md;lambda {md_arr; erb :md};end

  def links;lambda { haml :links };end

  def examples;lambda { haml :examples };end

  def graph;lambda {haml :graph};end
  
  def rdoc;lambda {rd_arr ; erb :rdoc };end

  def gm;lambda { markdown :"gm", to_erb };end

end