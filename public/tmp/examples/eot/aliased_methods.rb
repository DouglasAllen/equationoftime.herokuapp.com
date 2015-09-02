# aliased_methods.rb

class Equation_of_Time

  # alias for deg_to_rad
  
  def degrees_to_radians( degrees = 0.0 )  alias degrees_to_radians deg_to_rad
    degrees.nil? ? degrees = 0.0 : degrees
    degrees * PI / 180.0
  end
  
   # alias for delta_oblique
  
  def delta_t_ecliptic( ta = A2000 )  alias delta_t_ecliptic delta_oblique
    ta = check_jct_zero( ta )
    ma = ma_Sun( ta )      
    ratio = 4.0 * factor / 360.0
    ratio * (
             tl_Sun( ta, ma ) - 
             ra_Sun( ta, ma )
            )     
  end  

  # alias for delta_orbit
  
  def delta_t_elliptic( ta = A2000 )  alias delta_t_elliptic delta_orbit
    ta    = check_jct_zero( ta )
    ma    = ma_Sun( ta )      
    ratio = 4.0 * factor / 360.0
    ratio * ( ma - ta_Sun( ta, ma ) )
  end
  
    # alias for degrees_to_s
  
  def display_degrees( degrees = 0 )  alias display_degrees degrees_to_s
    degrees.nil? ? degrees = 0 : degrees = degrees
    degrees < 0 ? 
    sign_string                    = "-" :
    sign_string                    = "+"
    
    absolute_degrees               = degrees.abs

    absolute_degrees_integer       = Integer( absolute_degrees )
    absolute_decimal_minutes       = 60.0 * ( 
                                             absolute_degrees            - 
                                             absolute_degrees_integer 
                                             )
    absolute_minutes_integer       = Integer( absolute_decimal_minutes )
    absolute_decimal_seconds       = bd(
                                        60.0 * ( 
                                                absolute_decimal_minutes - 
                                                absolute_minutes_integer
                                                )
                                        )  * 1.0   
    absolute_seconds_integer       = Integer( absolute_decimal_seconds )
    absolute_milli_seconds_integer = Integer(
                                             (
                                              absolute_decimal_seconds   - 
                                              absolute_seconds_integer
                                              ) * 1000.0
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

  # alias for string_time
  
  def display_time( time = DT2000 ) alias display_time string_time
    time = check_t_zero( time )    
    
    if time.class == DateTime
      hours      = time.hour
      minutes    = time.min
      seconds    = time.sec
      intsecs    = Integer( seconds )
      decsecs    = Integer( ( seconds - intsecs ).round( 3 ) * 1000.0 )
    else      
      decimal    = time % DAY_HOURS
      hours      = Integer( decimal )
      mindecimal = bd( 60.0 * ( decimal - hours ) ) * 1.0
      minutes    = Integer( mindecimal )
      seconds    = bd( 60.0 * ( mindecimal - minutes ) ) * 1.0    
      intsecs    = Integer( seconds )
      decsecs    = Integer( ( seconds - intsecs ).round( 3 ) * 1000.0 )
    end
    
    "%02d" % hours   +
                 ":" + 
    "%02d" % minutes + 
                 ":" + 
    "%02d" % intsecs +
                 "." +
    "%3.3d" % decsecs
  end    

  # alias for mo_Earth
  
  def mean_obliquity_of_ecliptic( ta = A2000 )  alias mean_obliquity_of_ecliptic mo_Earth
    ta = check_jct_zero( ta )
    # t = t / 3600.0
    # t2 = t * t
    # t3 = t2 * t
    # t4 = t3 * t
    # t5 = t4 * t
    ( 
           84381.406         -
     ta[ 0 ] * 46.836769      - 
     ta[ 1 ] *  0.0001831     + 
     ta[ 2 ] *  0.00200340    - 
     ta[ 3 ] *  0.000000576   - 
     ta[ 4 ] *  0.0000000434
     ) / ARCSEC
  end   
  
    # alias for to_Earth
  
  def obliquity_correction( ta = A2000 )  alias obliquity_correction to_Earth
    ta = check_jct_zero( ta )
    (mean_obliquity_of_ecliptic( ta ) + 
                 delta_epsilon( ta )).round(14)
  end
  
  # alias for string_to_Earth
  
  def string_obliquity_correction( ta = A2000 )  alias string_obliquity_correction string_to_Earth
    ta = check_jct_zero( ta )
    display_degrees( obliquity_correction( ta ) )
  end   
  
  # alias for rad_to_deg

  def radians_to_degrees( radians = 0.0 )  alias radians_to_degrees rad_to_deg
    radians.nil? ? radians = 0.0 : radians
    radians * 180.0 / PI
  end  

  # alias for time_julian_century
  
  def time_julian_centurey( dt = DT2000 )  alias time_julian_centurey time_julian_century
    dt = check_t_zero( dt )  
    dt.class == DateTime ? jd = dt.jd : jd = dt
    
    t1 = ( jd - J2000 ) / 36525.0
    t2 = t1 * t1
    t3 = t1 * t2
    t4 = t1 * t3
    t5 = t1 * t4
    [ t1, t2, t3, t4, t5 ]       
  end
  
  # alias for mod_360
  
  def truncate( x = 0.0 )  alias truncate mod_360    
    x.nil? ? x = 0.0 : x
    360.0 * ( x / 360.0 - Integer( x / 360.0 ) )
  end 
    
end