# geo_spec.rb/
gem 'minitest'
require 'minitest/autorun'

lib = File.expand_path('../../../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless$LOAD_PATH.include?(lib)
require 'eot'

geo = GeoLatLng.new

describe 'Geo defaults' do

  INTERNATIONAL = geo.default_int
  it "expected #{INTERNATIONAL}" do
    assert_equal INTERNATIONAL, geo.addr
  end

  BASE = 'http://maps.googleapis.com/maps/api/geocode/json?sensor=false&address='
  it "expected #{BASE}" do
    assert_equal BASE, geo.base_json
  end

  it 'expected #{INTERNATIONAL 'do
    assert_equal INTERNATIONAL, geo.default_int
  end

  DEFAULT_US = '3333 Coyote Hill Road, Palo Alto, CA, 94304, USA'
  it 'expected   DEFAULT_US 'do
    assert_equal DEFAULT_US, geo.default_us
  end

  it 'expected   0.0'do
    assert_equal 0.0, geo.lat
  end

  it 'expected   0.0'do
    assert_equal 0.0, geo.lng
  end

end
