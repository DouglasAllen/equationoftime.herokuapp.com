##
# class Eot file = times.rb:
# methods calculating times

class Eot

  ##
  # From times.rb:

  # Pass in an AJD number
  # Returns a DateTime object
  # only DateTime#jd() to work with so
  # add a half day to make it work.

  def ajd_to_datetime(ajd)
    DateTime.jd(ajd + 0.5)
  end

  # From times.rb:
  # Uses @ajd attribute
  # Returns astronomical twilight end as a DateTime
  def astronomical_twilight_end_dt
    ajd_to_datetime(astronomical_twilight_end_jd)
  end

  # From times.rb:
  # Uses @ajd attribute
  # Returns astronomical twilight start as a DateTime
  def astronomical_twilight_start_dt
    ajd_to_datetime(astronomical_twilight_start_jd)
  end

  # From times.rb:
  # Uses @ajd attribute
  # Returns civil twilight end as a DateTime
  def civil_twilight_end_dt
    ajd_to_datetime(civil_twilight_end_jd)
  end

  # From times.rb:
  # Uses @ajd attribute
  # Returns civil twilight start as a DateTime
  def civil_twilight_start_dt
    ajd_to_datetime(civil_twilight_start_jd)
  end

  # From times.rb:
  # Uses @ajd and @longitude attributes
  # Returns DateTime object of local noon or solar transit
  def local_noon_dt
    ajd_to_datetime(mean_local_noon_jd - eot_jd)
  end

  # From times.rb:
  # Uses @ajd attribute
  # Returns nautical twilight end as a DateTime
  def nautical_twilight_end_dt
    ajd_to_datetime(nautical_twilight_end_jd)
  end

  # From times.rb:
  # Uses @ajd attribute
  # Returns nautical twilight start as a DateTime
  def nautical_twilight_start_dt
    ajd_to_datetime(nautical_twilight_start_jd)
  end

  # From times.rb:
  # sets @ajd to DateTime.now
  # Returns EOT (equation of time) now in decimal minutes form
  def now
    @ajd = DateTime.now.to_time.utc.to_datetime.ajd
    @ta = (@ajd - DJ00) / DJC
    time_eot
  end

  # From times.rb:
  # Uses @ajd attribute
  # Returns a DateTime object of local sunrise
  def sunrise_dt
    ajd_to_datetime(sunrise_jd)
  end

  # From times.rb:
  # Uses @ajd attribute
  # Returns a DateTime object of local sunset
  def sunset_dt
    ajd_to_datetime(sunset_jd)
  end
end

if __FILE__ == $PROGRAM_NAME

  spec = File.expand_path('../../../tests/minitest', __FILE__)
  $LOAD_PATH.unshift(spec) unless $LOAD_PATH.include?(spec)
  require 'times_spec'

end
