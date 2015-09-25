# environment.rb
#

if ENV.fetch("RACK_ENV") == "development"
  p "you're in #{__FILE__}"
end

require File.expand_path('../application', __FILE__)

#IRB.start # uncomment to use irb
