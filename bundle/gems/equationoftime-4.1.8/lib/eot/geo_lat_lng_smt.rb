# class GeoLatLng file = geo_lat_lng_smt.rb
# class for location coordinates lookup
class GeoLatLng
  # Base address for Google maps api
  attr_reader :base_json

  # Default US set to PARCS
  attr_reader :default_us

  # Default International set to GMT Museum
  attr_reader :default_int

  # Address entered
  attr_accessor :addr

  # Latitude returned
  attr_accessor :lat

  # Longitude returned
  attr_accessor :lng

  # Instance variables
  def initialize
    @base_json      = 'http://maps.googleapis.com/maps/api/geocode/json?sensor=false&address='
    @default_us     = '3333 Coyote Hill Road, Palo Alto, CA, 94304, USA'
    @default_int    = 'Blackheath Ave, London SE10 8XJ, UK'
    @addr           = @default_int
    @lat            = 0.0
    @lng            = 0.0
  end

  # coordinates lookup
  def set_coordinates
    addr = Addressable::URI.escape(@base_json + @addr)
    rest_resource = JSON.parse(RestClient.get(addr))
    results       = rest_resource['results']
    status        = rest_resource['status']
    if status != 'OK'
      @addr = @default_int
    else
      @lat   = results[0]['geometry']['location']['lat'].to_f
      @lng  = results[0]['geometry']['location']['lng'].to_f
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  lib = File.expand_path('../../../lib', __FILE__)
  $LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
  require 'eot'
  eot = Eot.new
  p eot.addr
  p eot.latitude
  p eot.longitude
  geo = GeoLatLng.new
  p geo.addr
  p geo.lat
  p geo.lng
  geo.get_coordinates
  p geo.lat
  p geo.lng
  spec = File.expand_path('../../../test/eot', __FILE__)
  $LOAD_PATH.unshift(spec) unless $LOAD_PATH.include?(spec)
  require 'geo_spec'
  system 'bundle exec ruby ~/workspace/equationoftime/test/eot/geo_spec.rb'
end
