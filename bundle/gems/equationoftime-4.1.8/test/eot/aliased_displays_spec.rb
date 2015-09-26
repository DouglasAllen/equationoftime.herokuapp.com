# aliased_displays_spec.rb
gem 'minitest'
require 'minitest/autorun'

lib = File.expand_path('../../../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'eot'

aliased_displays = Eot.new

describe 'aliased_displays using ajd of 2456885.0' do

  before(:each) do
    aliased_displays.ajd  = 2_456_885.0
    ajd = aliased_displays.ajd
    aliased_displays.ma_ta_set
    # check date for this ajd when needed.
    aliased_displays.date = aliased_displays.ajd_to_datetime(ajd)

  end

  it 'expected   2456885.0 , from aliased_displays.' do
    assert_equal 2_456_885.0, aliased_displays.ajd
  end

  it 'expected   "2014-08-15T12:00:00+00:00", \
      from aliased_displays.date.to_s' do
    assert_equal '2014-08-15T12:00:00+00:00', aliased_displays.date.to_s
  end

  it 'expected   3.8508003966038915, from aliased_displays.' do
    assert_equal 3.8508003966038915, aliased_displays.ma
  end

  it 'expected   "+142:35:33.356" \
      from aliased_displays.apparent_longitude_string()? ' do
    assert_equal '+142:35:33.356', aliased_displays.apparent_longitude_string
  end

  it 'expected   "+013:58:51.522" \
      from aliased_displays.declination_string()? ' do
    assert_equal '+013:58:51.522', aliased_displays.declination_string
  end

  it 'expected   "-04m, 29.2s" from \
      aliased_displays.display_equation_of_time()? ' do
    assert_equal '-04m, 29.2s', aliased_displays.display_equation_of_time
  end

  it 'expected   "12:00:00.000" \
      from aliased_displays.display_time_string()? ' do
    assert_equal '12:00:00.000', aliased_displays.display_time_string
    assert_equal '12:00:00.000', aliased_displays.display_time_string(nil)
    assert_equal '12:00:00.000', aliased_displays.display_time_string(0)
  end

  it 'expected   "12:00:00.000" from \
      aliased_displays.display_time_string(aliased_displays.date)? ' do
    assert_equal '12:00:00.000', \
                 aliased_displays.display_time_string(aliased_displays.date)
  end

  it 'expected   "2000-01-01" from aliased_displays.jd_to_date_string()? ' do
    assert_equal '2000-01-01', aliased_displays.jd_to_date_string
    assert_equal '2000-01-01', aliased_displays.jd_to_date_string(nil)
    assert_equal '2000-01-01', aliased_displays.jd_to_date_string(0)
  end

  it 'expected   "2014-08-15" \
      from aliased_displays.jd_to_date_string(aliased_displays.ajd)? ' do
    assert_equal '2014-08-15', \
                 aliased_displays.jd_to_date_string(aliased_displays.ajd)
  end

  it 'expected   "12:00:00" from \
      aliased_displays.julian_period_day_fraction_to_time()? ' do
    assert_equal '12:00:00', \
                 aliased_displays.julian_period_day_fraction_to_time
    assert_equal '12:00:00', \
                 aliased_displays.julian_period_day_fraction_to_time(nil)
    assert_equal '12:00:00', \
                 aliased_displays.julian_period_day_fraction_to_time(0)
  end

  it 'expected   "+220:38:04.598" from \
      aliased_displays.mean_anomaly_string()? ' do
    assert_equal '+220:38:04.598', aliased_displays.mean_anomaly_string
  end

  it 'expected   "+144:56:36.571" from \
      aliased_displays.right_ascension_string()? ' do
    assert_equal '+144:56:36.571', aliased_displays.right_ascension_string
  end

  it 'expected   "+219:24:27.798" from \
      aliased_displays.true_anomaly_string()? ' do
    assert_equal '+219:24:27.798', aliased_displays.true_anomaly_string
  end

  it 'expected   "+142:35:47.318" from \
      aliased_displays.true_longitude_string()? ' do
    assert_equal '+142:35:47.318', aliased_displays.true_longitude_string
  end

  it 'expected   "+023:26:06.164" from \
      aliased_displays.true_obliquity_string()? ' do
    assert_equal '+023:26:06.164', aliased_displays.true_obliquity_string
  end

end

describe 'Eot aliased displays explicit values' do

  it 'expected   "16:40:40.800" from \
      aliased_displays.display_time_string(16.6780)? ' do
    assert_equal '16:40:40.800', \
                 aliased_displays.display_time_string(16.6780)
  end

  it 'expected   "17:59:16.800" from \
      aliased_displays.display_time_string(17988)? ' do
    aliased_displays.date = Date.today.to_s
    assert_equal '17:59:16.800', \
                 aliased_displays.display_time_string(17.988)
  end

end
