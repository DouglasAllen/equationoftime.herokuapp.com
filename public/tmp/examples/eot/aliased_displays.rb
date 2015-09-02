# aliased_displays.rb
#

class Equation_of_Time

  # alias for string_al_Sun
  # in aliased_displays.rb
  def apparent_longitude_string( ta = time_julian_century() ) alias apparent_longitude_string string_al_Sun
    degrees_to_s( al_Sun( ta ) )
  end 

  # alias for string_dec_Sun
  # in aliased_displays.rb
  def declination_string( ta = A2000 ) alias declination_string string_dec_Sun
    degrees_to_s( dec_Sun( ta ) )
  end  

  # alias for string_equation_of_time
  # in aliased_displays.rb
  def display_equation_of_time( ta = A2000 ) alias display_equation_of_time string_equation_of_time    
    eot = time_equation_of_time( ta )    
    min_equation_of_time = eot
    if min_equation_of_time < 0.0
      sign = "-"
    else
      sign = "+"
    end
    eot = min_equation_of_time.abs
    minutes = Integer( eot )
    seconds = ( eot - minutes ) * 60.0
    decimal_seconds = ( seconds - Integer( seconds )) * 100.0
    sign << "%02d" % minutes << "m, " << "%02d" %  seconds << "." << "%02d" % decimal_seconds << "s"
  end

  # alias for string_time
  # in aliased_displays.rb
  def display_time_string(dt = DT2000 ) alias display_time_string string_time
    dt = check_t_zero( dt )
    
    if dt.class == DateTime      
      hours   = dt.hour
      minutes = dt.min
      seconds = dt.sec
      intsecs = Integer( seconds )
      decsecs = Integer(( seconds - intsecs ).round( 3 ) * 1000.0 )
    else
      decimal = dt % DAY_HOURS
      hours = Integer( decimal )
      mindecimal = bd( 60.0 * ( decimal - hours )) * 1.0
      minutes = Integer( mindecimal )
      seconds = bd( 60.0 * ( mindecimal - minutes )) * 1.0    
      intsecs = Integer( seconds )
      decsecs = Integer(( seconds - intsecs ).round( 3 ) * 1000.0 )
    end
    
    "%02d" % hours   +
                 ":" + 
    "%02d" % minutes + 
                 ":" + 
    "%02d" % intsecs +
                 "." +
    "%3.3d" % decsecs
  end

  # alias for string_jd_to_date
  # in aliased_displays.rb  
  def jd_to_date_string( jd = J2000 )  alias jd_to_date_string string_jd_to_date
    jd = check_jd_zero( jd )
    Date.jd( jd ).to_s
  end  

  # alias for string_day_fraction_to_time
  # in aliased_displays.rb  
  def julian_period_day_fraction_to_time(jpd_time = 0.0 ) alias julian_period_day_fraction_to_time string_day_fraction_to_time
    jpd_time.nil? ? jpd_time = 0.0 : jpd_time
    fraction = jpd_time + 0.5 - Integer( jpd_time )
    hours = Integer( fraction * DAY_HOURS )
    minutes = Integer(( fraction - hours / DAY_HOURS ) * DAY_MINUTES )
    seconds = Integer(( fraction - hours / 24.0 - minutes / DAY_MINUTES ) * DAY_SECONDS )
    "%02d" % hours   +
    ":"              +
    "%02d" % minutes +
    ":"              +
    "%02d" % seconds
  end
  
  # alias for string_ma_Sun
  # in aliased_displays.rb  
  def mean_anomaly_string(ta = A2000 ) alias mean_anomaly_string string_ma_Sun
    degrees_to_s( ma_Sun( ta ) )
  end
  
  # alias for string_ra_Sun
  # in aliased_displays.rb
  def right_ascension_string( ta = A2000 ) alias right_ascension_string string_ra_Sun
    degrees_to_s( ra_Sun( ta ) )
  end 
 
  # alias for string_ta_Sun
  # in aliased_displays.rb
  def true_anomaly_string( ta = A2000 ) alias true_anomaly_string string_ta_Sun 
    degrees_to_s( ta_Sun( ta ) )
  end
 
  # alias for string_tl_Sun
  # in aliased_displays.rb
  def true_longitude_string( ta = A2000 ) alias true_longitude_string string_tl_Sun
    degrees_to_s( tl_Sun( ta ) )
  end  

  # alias for string_to_Earth
  # in aliased_displays.rb
  def true_obliquity_string( ta = A2000 ) alias true_obliquity_string string_to_Earth
    degrees_to_s( to_Earth( ta ) )
  end

end
if __FILE__ == $PROGRAM_NAME
end