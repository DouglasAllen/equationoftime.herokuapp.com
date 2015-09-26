# constants_spec.rb
gem 'minitest'
require 'minitest/autorun'
lib = File.expand_path('../../../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'eot'

describe 'Equation of Time constants.' do

  it "01 require 'eot' should find all constants." do
    assert_equal 24.0, Eot::DAY_HOURS
    assert_equal 1440.0, Eot::DAY_MINUTES
    assert_equal 86_400.0, Eot::DAY_SECONDS
    assert_equal 86_400.0 * 1.0e+6, Eot::DAY_USECS
    assert_equal 57.29577951308232, Eot::R2D
    assert_equal 0.017453292519943295, Eot::D2R
  end
end
