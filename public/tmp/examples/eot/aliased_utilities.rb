# aliased_utilities.rb
#

class Equation_of_Time
   
  # alias for deg_to_rad in aliased_utilities.rb     
  def degrees_to_radians( degrees = 0.0 )  alias degrees_to_radians deg_to_rad
    degrees.nil? ? degrees = 0.0 : degrees
    degrees * PI / 180.0
  end
  
  # alias for rad_to_deg in aliased_utilities.rb
  def radians_to_degrees( radians = 0.0 )  alias radians_to_degrees rad_to_deg
    radians.nil? ? radians = 0.0 : radians
    radians * 180.0 / PI
  end  
  
  # alias for mod_360 in aliased_utilities.rb  
  def truncate( x = 0.0 )  alias truncate mod_360    
    x.nil? ? x = 0.0 : x
    360.0 * ( x / 360.0 - Integer( x / 360.0 ) )
  end

end
if __FILE__ == $PROGRAM_NAME
end  