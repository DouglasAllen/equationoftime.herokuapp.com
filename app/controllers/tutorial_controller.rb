#require_relative '../controllers/application_controller'

class TutorialController# < ApplicationController

  if ENV.fetch("RACK_ENV") == "development"
    p "you're in #{__FILE__}"
  end

  def datetime;lambda {haml :datetime};end

  def jcft;lambda {haml :jcft};end

  def mean;lambda {haml :mean};end

  def eqc;lambda {haml :eqc};end

  def ecliplon;lambda {haml :ecliplon};end

  def ra;lambda {haml :rghtascn};end

  def final;lambda {haml :final};end

  #def eot;lambad {haml :eot};end

end
