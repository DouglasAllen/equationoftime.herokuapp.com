# aliased_angles_spec.rb
gem 'minitest'
require 'minitest/autorun'

lib = File.expand_path('../../../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'eot'

aliased_angles = Eot.new

describe 'tests ajd of 2456885.0 ' do

  before(:each) do
    aliased_angles.ajd  = 2_456_885.0
    ajd = aliased_angles.ajd
    aliased_angles.ma_ta_set
    # somtimes need date to check values somewhere else
    aliased_angles.date = aliased_angles.ajd_to_datetime(ajd)
  end

  it 'expected   2_456_885.0 for aliased_angles.ajd 'do
    assert_equal(2_456_885.0, aliased_angles.ajd)
  end

  it 'expected   "2014-08-15T12:00:00+00:00" from \
      aliased_angles.date.to_s ' do
    assert_equal('2014-08-15T12:00:00+00:00', aliased_angles.date.to_s)
  end

  it 'expected   3.8508003966038915 from aliased_angles.ma 'do
    assert_equal(3.8508003966038915, aliased_angles.ma)
  end

  it 'expected   2.4887103398436143 from \
      aliased_angles.apparent_longitude()? ' do
    assert_equal(2.4887103398436143, aliased_angles.apparent_longitude)
  end

  it 'expected   -0.7943361570447028 from \
      aliased_angles.cosine_apparent_longitude()? ' do
    assert_equal(-0.7943361570447028, \
                 aliased_angles.cosine_apparent_longitude)
  end

  it 'expected   -0.7943772759574919 from \
      aliased_angles.cosine_true_longitude()? ' do
    assert_equal(-0.7943772759574919, aliased_angles.cosine_true_longitude)
  end

  it 'expected   0.9175115346811911 from \
      aliased_angles.cosine_true_obliquity()? ' do
    assert_equal(0.9175115346811911, aliased_angles.cosine_true_obliquity)
  end

  it 'expected   0.24401410218543554 from \
      aliased_angles.declination()? ' do
    assert_equal(0.24401410218543554, aliased_angles.declination)
  end

  it 'expected   -0.04103082558803539 from \
      aliased_angles.delta_t_ecliptic()? ' do
    assert_equal(-0.04103082558803539, aliased_angles.delta_t_ecliptic)
  end

  it 'expected   0.021413249720702462 from \
      aliased_angles.delta_t_elliptic()? ' do
    assert_equal(0.021413249720702462, aliased_angles.delta_t_elliptic)
  end

  it 'expected   0.016702468499021204 from \
      aliased_angles.eccentricity_earth_orbit()? ' do
    assert_equal(0.016702468499021204, \
                 aliased_angles.eccentricity_earth_orbit)
  end

  it 'expected   -0.021413249720702462 from \
      aliased_angles.equation_of_center()? ' do
    assert_equal(-0.021413249720702462, aliased_angles.equation_of_center)
  end

  it 'expected   2.5101912804141424 from \
      aliased_angles.geometric_mean_longitude()? ' do
    assert_equal(2.5101912804141424, \
                 aliased_angles.geometric_mean_longitude)
  end

  it 'expected   1.5857841877939605 from \
      aliased_angles.horizon_angle(1)? ' do
    assert_equal(1.5857841877939605, aliased_angles.horizon_angle(1))
  end

  it 'expected   3.8508003966038915 from \
      aliased_angles.mean_anomaly()? ' do
    assert_equal(3.8508003966038915, aliased_angles.mean_anomaly)
  end

  it 'expected   2.510089864980358 from \
      aliased_angles.mean_longitude_aries()? ' do
    assert_equal(2.510089864980358, aliased_angles.mean_longitude_aries)
  end

  it 'expected   0.40905940254265843 from \
      aliased_angles.mean_obliquity()? ' do
    assert_equal(0.40905940254265843, aliased_angles.mean_obliquity)
  end

  it 'expected   0.40905940254265843 from \
      aliased_angles.mean_obliquity_of_ecliptic()? ' do
    assert_equal(0.40905940254265843, \
                 aliased_angles.mean_obliquity_of_ecliptic)
  end

  it 'expected   0.40901870461547685 from \
      aliased_angles.obliquity_correction()? ' do
    assert_equal(0.40901870461547685, aliased_angles.obliquity_correction)
  end

  it 'expected   2.5297411654316497 from \
      aliased_angles.right_ascension()? ' do
    assert_equal(2.5297411654316497, aliased_angles.right_ascension)
  end

  it 'expected   0.6074784519729512 from \
      aliased_angles.sine_apparent_longitude()? ' do
    assert_equal(0.6074784519729512, aliased_angles.sine_apparent_longitude)
  end

  it 'expected   0.6074246812917259 from \
      aliased_angles.sine_true_longitude()? ' do
    assert_equal(0.6074246812917259, aliased_angles.sine_true_longitude)
  end

  it 'expected   3.8293871468831893 from \
      aliased_angles.true_anomaly()? ' do
    assert_equal(3.8293871468831893, aliased_angles.true_anomaly)
  end

  it 'expected   2.48877803069344 from \
      aliased_angles.true_longitude()? ' do
    assert_equal(2.48877803069344, aliased_angles.true_longitude)
  end

  it 'expected   2.5101242776531474 from \
      aliased_angles.true_longitude_aries()? ' do
    assert_equal(2.5101242776531474, aliased_angles.true_longitude_aries)
  end

  it 'expected   0.40901870461547685 from \
      aliased_angles.true_obliquity()? ' do
    assert_equal(0.40901870461547685, aliased_angles.true_obliquity)
  end
end

describe 'tests ajd of 2455055.5 ' do

  before(:each) do
    aliased_angles.ajd                   = 2_455_055.0
    ajd = aliased_angles.ajd
    aliased_angles.ma_ta_set
    # check date for this ajd when needed.
    aliased_angles.date = aliased_angles.ajd_to_datetime(ajd)
  end

  it 'expected   2_455_055.0, from aliased_angles.' do
    assert_equal(2_455_055.0, aliased_angles.ajd)
  end

  it 'expected   "2009-08-11T12:00:00+00:00" from \
      aliased_angles.date.to_s ' do
    assert_equal('2009-08-11T12:00:00+00:00', aliased_angles.date.to_s)
  end

  it 'expected   3.7871218188949207, from aliased_angles.ma ' do
    assert_equal(3.7871218188949207, aliased_angles.ma)
  end

  it 'expected   3.7871218188949207 from \
      aliased_angles.ma  from Eot_angles.mean_anomaly() ' do
    assert_equal(3.7871218188949207, aliased_angles.mean_anomaly)
  end

  it 'expected   2.4252140645725033 from \
      aliased_angles.apparent_longitude()? ' do
    assert_equal(2.4252140645725033, aliased_angles.apparent_longitude)
  end

  it 'expected   -0.7541886969975007 from \
      aliased_angles.cosine_apparent_longitude()? ' do
    assert_equal(-0.7541886969975007, \
                 aliased_angles.cosine_apparent_longitude)
  end

  it 'expected   -0.7542060769936684 from \
      aliased_angles.cosine_true_longitude()? ' do
    assert_equal(-0.7542060769936684, aliased_angles.cosine_true_longitude)
  end

  it 'expected   0.9174818088112336 from \
      aliased_angles.cosine_true_obliquity()? ' do
    assert_equal(0.9174818088112336, aliased_angles.cosine_true_obliquity)
  end

  it 'expected   0.2642691272294404 from \
      aliased_angles.declination()? ' do
    assert_equal(0.2642691272294404, aliased_angles.declination)
  end

  it 'expected   -0.04234904897476355 from \
      aliased_angles.delta_t_ecliptic()? ' do
    assert_equal(-0.04234904897476355, aliased_angles.delta_t_ecliptic)
  end

  it 'expected    0.019768413456709915 from \
      aliased_angles.delta_t_elliptic()? ' do
    assert_equal(0.019768413456709915, aliased_angles.delta_t_elliptic)
  end

  it 'expected   0.016704576164208475 from \
      aliased_angles.eccentricity_earth_orbit()? ' do
    assert_equal(0.016704576164208475, \
                 aliased_angles.eccentricity_earth_orbit)
  end

  it 'expected   -0.019768413456709915 from \
      aliased_angles.equation_of_center()? ' do
    assert_equal(-0.019768413456709915, aliased_angles.equation_of_center)
  end

  it 'expected   2.445008945789877 from \
      aliased_angles.geometric_mean_longitude()? ' do
    assert_equal(2.445008945789877, aliased_angles.geometric_mean_longitude)
  end

  it 'expected   1.585863261753274 from \
      aliased_angles.horizon_angle()? ' do
    assert_equal(1.585863261753274, aliased_angles.horizon_angle(1))
  end

  it 'expected   3.7871218188949207 from \
      aliased_angles.mean_anomaly()? ' do
    assert_equal(3.7871218188949207, aliased_angles.mean_anomaly)
  end

  it 'expected   2.444907382260759 from \
      aliased_angles.mean_longitude_aries()? ' do
    assert_equal(2.444907382260759, aliased_angles.mean_longitude_aries)
  end

  it 'expected   0.4090707793981491 from \
      aliased_angles.mean_obliquity()? ' do
    assert_equal(0.4090707793981491, aliased_angles.mean_obliquity)
  end

  it 'expected   0.4090934409048494 from \
      aliased_angles.obliquity_correction()? ' do
    assert_equal(0.4090934409048494, aliased_angles.obliquity_correction)
  end

  it 'expected   2.467563113547267 from \
      aliased_angles.right_ascension()? ' do
    assert_equal(2.467563113547267, aliased_angles.right_ascension)
  end

  it 'expected   0.6566577566139093 from \
      aliased_angles.sine_apparent_longitude()? ' do
    assert_equal(0.6566577566139093, aliased_angles.sine_apparent_longitude)
  end

  it 'expected   0.6566377946979757 from \
      aliased_angles.sine_true_longitude()? ' do
    assert_equal(0.6566377946979757, aliased_angles.sine_true_longitude)
  end

  it 'expected   3.767353405438211 from aliased_angles.true_anomaly()? ' do
    assert_equal(3.767353405438211, aliased_angles.true_anomaly)
  end

  it 'expected   2.4252405323331674 from \
      aliased_angles.true_longitude()? ' do
    assert_equal(2.4252405323331674, aliased_angles.true_longitude)
  end

  it 'expected   2.4449774607872907 from \
      aliased_angles.true_longitude_aries()? ' do
    assert_equal(2.4449774607872907, aliased_angles.true_longitude_aries)
  end

  it 'expected   0.4090934409048494 from \
      aliased_angles.true_obliquity()? ' do
    assert_equal(0.4090934409048494, aliased_angles.true_obliquity)
  end

end
