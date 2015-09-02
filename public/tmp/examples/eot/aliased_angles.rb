# aliased_angles.rb
#

class Equation_of_Time
  
  # alias for al_Sun in aliased_angles.rb
    # in aliased_angles.rb
  def apparent_longitude( ta = A2000 )  alias  apparent_longitude al_Sun           
    ta = check_jct_zero( ta )
    tl_Sun( ta ) - 0.00569 - 0.00478 *  
	  sin( deg_to_rad( omega( ta ) ) )
  end
  
  # alias for cosine_al_Sun in aliased_angles.rb
    # in aliased_angles.rb  
  def cosine_apparent_longitude( ta = A2000 ) alias cosine_apparent_longitude cosine_al_Sun
    ta = check_jct_zero( ta )
    cos( deg_to_rad( al_Sun( ta ) ) )
  end  
  
  # alias for cosine_tl_Sun in aliased_angles.rb
    # in aliased_angles.rb
  def cosine_true_longitude( ta = A2000 )  alias cosine_true_longitude cosine_tl_Sun
    ta = check_jct_zero( ta )
    cos( deg_to_rad( tl_Sun( ta ) ) )
  end
  
  # alias for cosine_to_Earth in aliased_angles.rb
    # in aliased_angles.rb  
  def cosine_true_obliquity( ta = A2000 ) alias cosine_true_obliquity cosine_to_Earth
    ta = check_jct_zero( ta )
    cos( deg_to_rad( to_Earth( ta ) ) )
  end      
  
  #alias for dec_Sun in aliased_angles.rb
    # in aliased_angles.rb  
  def declination( ta = A2000 ) alias declination dec_Sun
    ta = check_jct_zero( ta )
    sine_declination = 
      sin( deg_to_rad( to_Earth( ta ) ) ) * 
      sine_al_Sun( ta )
      rad_to_deg( asin( sine_declination ) )
  end  
  
  # alias for delta_oblique in aliased_angles.rb  
    # in aliased_angles.rb  
  def delta_t_ecliptic( ta = A2000 )  alias delta_t_ecliptic delta_oblique
    ta = check_jct_zero( ta )
    ma = ma_Sun( ta )      
    tl_Sun( ta ) - 
    ra_Sun( ta )                 
  end  

  # alias for delta_orbit in aliased_angles.rb  
    # in aliased_angles.rb  
  def delta_t_elliptic( ta = A2000 )  alias delta_t_elliptic delta_orbit
    ta    = check_jct_zero( ta )
    ma    = ma_Sun( ta )      
    ma - ta_Sun( ta )
  end
  
  # alias for eccentricity_Earth in aliased_angles.rb
    # in aliased_angles.rb  
  def eccentricity_earth_orbit( ta = A2000 )  alias eccentricity_earth_orbit eccentricity_Earth
     ta = check_jct_zero( ta )      
     # 0.016708617 - ta[ 0 ] * ( 0.000042037 + ta[ 0 ] * 0.0000001235 )
	 [-0.0000001235, -0.000042037, 0.016708617].poly_eval( ta[0] )
  end  

  # alias for center in aliased_angles.rb
    # in aliased_angles.rb  
  def equation_of_center( ta = A2000, ma = ma_Sun( ta ))  alias equation_of_center center
    ta = check_jct_zero( ta )    
    sine_1M = sin( 1.0 * deg_to_rad( @ma ) )
    sine_2M = sin( 2.0 * deg_to_rad( @ma ) )
    sine_3M = sin( 3.0 * deg_to_rad( @ma ) )
    sine_4M = sin( 4.0 * deg_to_rad( @ma ) )
    sine_5M = sin( 5.0 * deg_to_rad( @ma ) )
    e = eccentricity_Earth( ta )
    rad_to_deg( sine_1M * ( 2 * e -  e**3/4 +  5/96 * e**5 ) +  
                sine_2M * (  5/4   * e**2   - 11/24 * e**4 ) + 
                sine_3M * ( 13/12  * e**3   - 43/64 * e**5 ) +
                sine_4M *  103/96  * e**4                    +
                sine_5M * 1097/960 * e**5 )
  end  
  
  # alias for gml_Sun in aliased_angles.rb
    # in aliased_angles.rb  
  def geometric_mean_longitude( ta = A2000 ) alias geometric_mean_longitude gml_Sun
    ta = check_jct_zero( ta )
    total =   280.4664567              +
            36000.76982779   * ta[ 0 ] +
                0.0003032028 * ta[ 1 ] +
        1.0/49931.0          * ta[ 2 ] -
        1.0/15299.0          * ta[ 3 ] -
      1.0/1988000.0          * ta[ 4 ] 
    mod_360( total )
    total = [ 1.0/-19880000.0, 1.0/-152990.0, 1.0/499310.0,
              0.0003032028, 36000.76982779, 280.4664567 ]
    mod_360( total.poly_eval( ta[0] ) )
  end
  
  #alias for ha_Sun in aliased_angles.rb
    # in aliased_angles.rb  
  def horizon_angle( ta = A2000 ) alias horizon_angle ha_Sun
    ta = check_jct_zero( ta )
    zenith              = 90.8333
    cosine_zenith       = cos( deg_to_rad( zenith ) )
    cosine_declination  = cos( deg_to_rad( dec_Sun( ta ) ) )
    sine_declination    = sin( deg_to_rad( dec_Sun( ta ) ) )
    
    @latitude.nil? ? latitude = 0 : latitude = @latitude
    
    cosine_latitude     = cos( deg_to_rad( latitude ) )
    sine_latitude       = sin( deg_to_rad( latitude ) )
    # tangent_altitude    = cosine_zenith / cosine_declination * cosine_latitude
    # tangent_declination = sine_declination / cosine_declination
    # tangent_latitude    = sine_latitude / cosine_latitude
    top                 = cosine_zenith - sine_declination * sine_latitude
    bottom              = cosine_declination * cosine_latitude
    t_cosine = top / bottom
    p 
    t_cosine > 1.0 || t_cosine < -1.0 ? cos = 1.0 : cos = t_cosine
    rad_to_deg( acos( cos ) ) 
  end

  # alias for ma_Sun in aliased_angles.rb
    # in aliased_angles.rb  
  def mean_anomaly( ta = A2000 ) alias mean_anomaly ma_Sun
    ta = check_jct_zero( ta )      
    @ma = mod_360( delta_equinox( ta )[ 2 ] / ARCSEC )      
  end  

  # alias for ml_Aries in aliased_angles.rb
  # see http://www.iausofa.org/publications/aas04.pdf
    # in aliased_angles.rb  
  def mean_longitude_aries( ta = A2000 ) alias mean_longitude_aries ml_Aries
    ta     = check_jct_zero( ta )
    jd     = ta[ 0 ] * DJC # convert first term back to jdn - J2000
    # old terms 	
    # angle  = (36000.770053608 / DJC + 360) * jd  # 36000.770053608 = 0.9856473662862 * DJC
    # total = [ -1.0/3.8710000e7, 3.87930e-4, 0, 100.460618375 ].poly_eval( ta[0] ) + 180 + angle  
    # newer terms seem to be in arcseconds / 15.0    
    # 0.0000013, - 0.0000062, 0.0931118, 307.4771600, 8639877.3173760, 24110.5493771
    angle  = (35999.4888224 / DJC + 360) * jd     
    total  = angle + 280.460622404583    +
              ta[ 0 ] * 1.281154833333   +
              ta[ 1 ] * 3.87965833333e-4 -
              ta[ 2 ] * 2.58333333333e-8 +
              ta[ 3 ] * 5.41666666666e-9           
	  mod_360( total )      
  end

  # alias for mo_Earth in aliased_angles.rb
    # in aliased_angles.rb  
  def mean_obliquity( ta = A2000 )  alias mean_obliquity mo_Earth
    ta = check_jct_zero( ta )   
    [ -0.0000000434, -0.000000576,  0.00200340, 
      -0.0001831,   -46.836769, 84381.406 ].poly_eval( ta[0] ) / ASD	
  end  

  # alias for mean_obliquity in aliased_angles.rb  
    # in aliased_angles.rb  
  def mean_obliquity_of_ecliptic( ta = A2000 )  alias mean_obliquity_of_ecliptic mean_obliquity
    ta = check_jct_zero( ta )     
    [ -0.0000000434, -0.000000576,  0.00200340, 
      -0.0001831,   -46.836769, 84381.406 ].poly_eval( ta[0] ) / ASD
  end 
  
  # alias for true_obliquity in aliased_angles.rb  
    # in aliased_angles.rb  
  def obliquity_correction( ta = A2000 ) alias obliquity_correction true_obliquity
    ta = check_jct_zero( ta )
    delta_epsilon( ta ) +
    mo_Earth( ta )    
  end 

  # alias for ra_Sun in aliased_angles.rb
    # in aliased_angles.rb  
  def right_ascension( ta = A2000 )  alias right_ascension ra_Sun
    ta = check_jct_zero( ta )
    y0 = sine_al_Sun( ta ) * cosine_to_Earth( ta )
    180.0 +           
    rad_to_deg( atan2( -y0, -cosine_al_Sun( ta ) ) )    
  end
  
  # alias for sine_al_Sun in aliased_angles.rb
    # in aliased_angles.rb  
  def sine_apparent_longitude( ta = A2000 )  alias sine_apparent_longitude sine_al_Sun
    ta = check_jct_zero( ta )
    sin( deg_to_rad( al_Sun( ta ) ) )
  end
  
  # alias for sine_tl_Sun in aliased_angles.rb
    # in aliased_angles.rb  
  def sine_true_longitude( ta = A2000 )  alias sine_true_longitude sine_tl_Sun
    ta = check_jct_zero( ta )
    sin( deg_to_rad( tl_Sun( ta ) ) )
  end  
  
  # alias for ta_Sun in aliased_angles.rb
    # in aliased_angles.rb  
  def true_anomaly( ta = A2000 )  alias true_anomaly ta_Sun    
    ta = check_jct_zero( ta )
    ma + center( ta )
  end  

  # alias for tl_Sun in aliased_angles.rb
    # in aliased_angles.rb  
  def true_longitude( ta = A2000 )  alias true_longitude tl_Sun
    ta = check_jct_zero( ta )
    mod_360( 
	          gml_Sun( ta ) + 
             center( ta )
           )
  end    
  
  # alias tl_Aries in aliased_angles.rb
    # in aliased_angles.rb  
  def true_longitude_aries( ta = A2000 )  alias true_longitude_aries tl_Aries     
    ta = check_jct_zero( ta )
    eq_of_equinox( ta ) +
         ml_Aries( ta )  
  end
  
  # alias for to_Earth in aliased_angles.rb
    # in aliased_angles.rb  
  def true_obliquity( ta = A2000 )  alias true_obliquity to_Earth
    ta = check_jct_zero( ta )
    delta_epsilon( ta ) +
         mo_Earth( ta )   
  end  
    
end
if __FILE__ == $PROGRAM_NAME
end