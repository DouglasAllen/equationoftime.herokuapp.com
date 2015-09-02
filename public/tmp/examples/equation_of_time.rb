# equation_of_time.rb

require 'eot/version'
require 'eot/constants'
require 'eot/init'
require 'eot/vars'
require 'eot/utilities'
require 'eot/angles'
require 'eot/times'
require 'eot/displays'
require 'eot/nutation'
require 'eot/geo_lat_lng_smt'
require 'eot/aliased_angles'
require 'eot/aliased_displays'
require 'eot/aliased_times'
require 'eot/aliased_utilities'
require 'astro-algo'
require 'lunaryear'
class Equation_of_Time
  include Astro
  include LunarYear
end
#require 'bigdecimal'
#require 'safe_yaml'
# 'time' can do some parsing.
#require 'time'

# for other time equations see:
# https://gist.github.com/2032003
# https://github.com/DouglasAllen/



