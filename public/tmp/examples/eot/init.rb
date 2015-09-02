# init.rb

require 'celes'
require_relative 'geo_lat_lng_smt'
require_relative 'times'

class Eot
      

  # From init.rb:<br>
  # address used for GeoLatLng.addr
  attr_accessor :addr
  
  # From init.rb:<br>
  # Astronomical Julian Day Number is an instance of DateTime class.
  # When new Equation of Time class is initialized @ajd = DateTime.jd
  attr_accessor :ajd
  
  # Method for change of @ajd from the default so @ma will get set anew.
  # Calling ma_Sun method will set @ta so be sure to not set @ma directly.
  def ajd=(ajd)
    @ajd = ajd.to_f
    @ta = (( @ajd - DJ00 ) / DJC).to_f
    @ma = Celes.falp03(@ta)
  end

  # From init.rb:<br>
  # Nutation Data is an instance of Array class.
  # @data = nutation_table5_3a.yaml 
  # YAML File loaded when new Eot class is initialized.
  #attr_reader :data  

  # From init.rb:<br>
  # @date is an instance of DateTime class.  
  # When new Eot class is initialized @date = now UTC  
  attr_accessor :date

  # From init.rb:<br>
  # Julian Day Number is an instance of DateTime class.
  # When new Eot class is initialized @jd = DateTime.jd  
  attr_accessor :jd

  # From init.rb:<br>
  # Latitude input is an instance of Float class.
  # When new Eot class is initialized @latitude = 0.0
  # May use GeoLatLng class to set it also but please comment that out  
  # if no internet connection is present via proxies or firewalls :D  
  attr_accessor :latitude
  
  # From init.rb:<br>
  # Longitude input is an instance of Float class.
  # When new Eot class is initialized @longitude = 0.0
  # May use GeoLatLng class to set it also but please comment that out 
  # if no internet connection is present via proxies or firewalls :D   
  attr_accessor :longitude

  # From init.rb:<br>
  # Mean Anomaly gets called a lot so class attribute saves it. 
  attr_accessor :ma
  

  # From init.rb:<br>
  # JCT gets called a lot so class attribute it.
  # Setting @ajd or @ma will set this  
  attr_accessor :ta
      
  # From init.rb:<br>
  # Initialize to set attributes 
  # You may use GeoLatLng to set up @latitude and @longitude but you need to have
  # internet so if not please comment it out for now.    
  def initialize(addr=nil)

    # file_path     = File.expand_path( File.dirname( __FILE__ ) + "/nutation_table5_3a.yaml" )
    # @data         = YAML::load( File.open( file_path, 'r'), :safe => true  ).freeze
 
    # set all date and time from this attribute
    @ajd = DateTime.now.to_time.utc.to_datetime.jd.to_f
    @jd = @ajd
    @date = ajd_to_datetime(@ajd) 
    @ta = (( @ajd - DJ00 ) / DJC).to_f
    @ma = Celes.falp03(@ta)                                      
    
    # comment out below if you do not have internet connection
    geo = GeoLatLng.new()   
    @addr = geo.addr           
    geo.get_coordinates_from_address
    @latitude.nil?  ? @latitude = geo.lat : @latitude
    @longitude.nil? ? @longitude = geo.lng : @longitude
  end
  
end


# we can run some tests from inside this file.
if __FILE__ == $PROGRAM_NAME

  lib = File.expand_path('../../../lib', __FILE__)
  $LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
  require 'eot'
  eot = Eot.new

  p eot.ajd
  p eot.date
  p eot.jd

  p eot.ma
  p eot.ta
  p eot.addr
  p eot.latitude
  p eot.longitude
  
  spec = File.expand_path('../../../tests/minitest', __FILE__)
  $LOAD_PATH.unshift(spec) unless $LOAD_PATH.include?(spec)
  require 'init_spec'

end
