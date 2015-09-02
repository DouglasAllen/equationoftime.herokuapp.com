# aliased_times.rb
#

class Equation_of_Time

  # alias for time_julian_century in aliased_times.rb  
  def time_julian_centurey( dt = DT2000 )  alias time_julian_centurey time_julian_century
    dt  = check_t_zero( dt )      	  
    dt.class == DateTime ? jd = dt.jd : jd = dt
    t1 = ( jd - J2000 ) / 36525.0
    t2 = t1 * t1
    t3 = t1 * t2
    t4 = t2 * t2
    t5 = t2 * t3
	  t6 = t3 * t3
	  t7 = t3 * t4
	  t8 = t4 * t4
	  t9 = t4 * t5
	  t10 = t5 * t5
    [ t1, t2, t3, t4, t5, t6, t7, t8, t9, t10 ]      
  end
  
end
if __FILE__ == $PROGRAM_NAME
end