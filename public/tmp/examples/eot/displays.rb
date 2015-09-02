# displays.rb

class Eot

  # From displays.rb<br>
  # String formatter for d:m:s display 
  def degrees_to_s( radians = 0.0 )
    radians.nil? ? radians = 0.0 : radians
    radians < 0 ? sign_string      = "-" : sign_string = "+"    
                  absolute_degrees = radians.abs * R2D
          absolute_degrees_integer = Integer( absolute_degrees )
          absolute_decimal_minutes = 60.0 * 
                                     (
                                      absolute_degrees - 
                                      absolute_degrees_integer
                                     )
                                     
          absolute_minutes_integer = Integer( absolute_decimal_minutes )
          
          absolute_decimal_seconds = 60.0 * 
                                     (
                                      absolute_decimal_minutes - 
                                      absolute_minutes_integer
                                      )
                                      
          absolute_seconds_integer = Integer( absolute_decimal_seconds )
          
    absolute_milli_seconds_integer = Integer(1000.0 *
	                                           (  
                                              absolute_decimal_seconds - 
                                              absolute_seconds_integer
                                             )
                                            )
                            sign_string +
      "%03d" % absolute_degrees_integer +
                                    ":" + 
      "%02d" % absolute_minutes_integer +
                                    ":" + 
      "%02d" % absolute_seconds_integer +
                                    "." + 
      "%3.3d" % absolute_milli_seconds_integer
  end  
  
  # From displays.rb<br>
  # String formatter for + and - time 
  def show_minutes(min = 0.0)
    min.nil? ? min = 0.0 : min
    time = Time.utc(1, 1, 1, 0, 0, 0, 0.0)
    time = time + (min.abs * 60.0)
    if min < 0.0
      sign = "-"
    else
      sign = "+"
    end
    time.strftime("#{sign}%M:%S.%3N")
  end

  # From displays.rb<br>
  # String for time now
  def show_now(now = now(Time.now.utc))
    show_minutes(now)
  end  
  
  # From displays.rb<br>
  # String format of apparent longitude 
  def string_al_Sun()
    degrees_to_s( al_Sun() )
  end
  alias_method :apparent_longitude_string, :string_al_Sun

  # From displays.rb<br>
  # String formatter for fraction of Julian day number
  def string_day_fraction_to_time( jpd_time = 0.0 )
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
  alias_method :julian_period_day_fraction_to_time, :string_day_fraction_to_time 

  # From displays.rb<br>
  # String format of declination 
  def string_dec_Sun()
    degrees_to_s( dec_Sun() )
  end
  alias_method :declination_string, :string_dec_Sun
  
  # From displays.rb<br>
  # String format for delta oblique
  def string_delta_oblique()
    show_minutes(delta_oblique())
  end
  
  # From displays.rb<br>
  # String format for delta orbit
  def string_delta_orbit()
    show_minutes(delta_orbit())
  end
  
  # From displays.rb<br>
  # String format for centre
  def string_eqc()
    degrees_to_s( center())
  end
  
  # From displays.rb<br>
  # Equation of time output for minutes and seconds
  def string_eot()    
    eot = time_eot()  
    min_eot = eot
    if min_eot < 0.0
      sign = "-"
    else
      sign = "+"
    end
    eot = min_eot.abs
    minutes = Integer( eot )
    seconds = ( eot - minutes ) * 60.0
    decimal_seconds = ( seconds - Integer( seconds )) * 100.0
    min = "%02d" % minutes
    sec = "%02d" %  seconds
    dec_sec = "%01d" % decimal_seconds
    sign << min << "m, " << sec << "." << dec_sec << "s"
  end 
  alias_method :display_equation_of_time, :string_eot 
  
  # From displays.rb<br>
  # String format conversion of jd to date
  def string_jd_to_date( jd = DJ00 )
    jd = check_jd_zero( jd )
    Date.jd( jd ).to_s
  end 
  alias_method :jd_to_date_string, :string_jd_to_date 

  # From displays.rb<br>
  # String format of mean anomaly    
  def string_ma_Sun()
    degrees_to_s( @ma )
  end
  alias_method :mean_anomaly_string, :string_ma_Sun 

  # From displays.rb<br>
  # String format of right ascension
  def string_ra_Sun()
    degrees_to_s( ra_Sun() )
  end
  alias_method :right_ascension_string, :string_ra_Sun     

  # From displays.rb<br>
  # String format of true anomaly  
  def string_ta_Sun( )
    degrees_to_s( ta_Sun() )
  end
  alias_method :true_anomaly_string, :string_ta_Sun

  # From displays.rb<br>
  # String formatter for h:m:s display 
  def string_time( dt = DT2000 )
    dt = check_t_zero( dt )
    
    if dt.class == DateTime      
      hours   = dt.hour
      minutes = dt.min
      seconds = dt.sec
      intsecs = Integer( seconds )
      decsecs = Integer(( seconds - intsecs ).round( 3 ) * 1000.0 )
    else
      decimal    = dt % DAY_HOURS
      hours      = Integer( decimal )
      mindecimal = 60.0 * ( decimal - hours )
      minutes    = Integer( mindecimal )
      seconds    = 60.0 * ( mindecimal - minutes )    
      intsecs    = Integer( seconds )
      decsecs    = Integer(( seconds - intsecs ).round( 3 ) * 1000.0 )
    end
    
    "%02d" % hours   +
                 ":" + 
    "%02d" % minutes + 
                 ":" + 
    "%02d" % intsecs +
                 "." +
    "%3.3d" % decsecs
  end
  alias_method :display_time_string, :string_time    

  # From displays.rb<br>
  # String format of true longitude 
  def string_tl_Sun()
    degrees_to_s( tl_Sun() )
  end
  alias_method :true_longitude_string, :string_tl_Sun 

  # From displays.rb<br>
  # String format of true obliquity 
  def string_to_Earth()
    degrees_to_s( to_Earth() )
  end
  alias_method :true_obliquity_string, :string_to_Earth 

end

if __FILE__ == $PROGRAM_NAME

  spec = File.expand_path('../../../tests/minitest', __FILE__)
  $LOAD_PATH.unshift(spec) unless $LOAD_PATH.include?(spec)
  require 'displays_spec'
  require 'aliased_displays_spec'

end