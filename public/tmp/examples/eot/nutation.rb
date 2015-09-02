# nutation.rb

#require_relative 'celes_core'
#require 'celes'

class Eot    
 
  # From nutation.rb<br>
  # Returns array with [ delta_eps, delta_psi, ma_sun, omega]
  # celes gem is used here now for performance. It is a Ruby wrapper for
  # see http://www.iausofa.org/
  # also see http://aa.usno.navy.mil/ Circular 179 nutation data page 46 (5.19)
  # Note: Original code is still intact just commented out. 
  def delta_equinox()      
    # Mean anomaly of the Moon. 
    # ma_moon = [-0.00024470, 0.051635, 31.8792, 1717915923.2178, 485868.249036].inject(0.0) {|p, a| p * @ta + a}		
    # ma_moon = Celes.fal03(@ta)
    # Mean anomaly of the Sun.
    # ma_sun  = [-0.00001149, 0.000136, -0.5532, 129596581.0481, 1287104.793048].inject(0.0) {|p, a| p * @ta + a}	
    # ma_sun  = Celes.falp03(@ta)
    # mean longitude of the Moon minus mean longitude of the ascending node.               
    # md_moon = [0.00000417, -0.001037, -12.7512, 1739527262.8478, 335779.526232].inject(0.0) {|p, a| p * @ta + a}
    # md_moon = Celes.faf03(@ta)
    # Mean elongation of the Moon from the Sun.        
    # me_moon = [-0.00003169, 0.006593, -6.3706, 1602961601.2090, 1072260.70369].inject(0.0) {|p, a| p * @ta + a} 
    # me_moon = Celes.fad03(@ta)
    # Mean longitude of the ascending node of the Moon.       
    # omega   = [-0.00005939, 0.007702, 7.4722, -6962890.5431, 450160.398036].inject(0.0) {|p, a| p * @ta + a}            
    # omega   = Celes.faom03(@ta)
    # declare and clear these two variables for the sigma loop
    # delta_psi, delta_eps = 0, 0

    # lines = data.size - 1
    # (0..lines).each do |i|
      # fma_sun    = data[i][0].to_i
      # fma_moon   = data[i][1].to_i  	
      # fmd_moon   = data[i][2].to_i
      # fme_moon   = data[i][3].to_i  
      # fomega     = data[i][4].to_i

      # sine       = sin(fma_moon * ma_moon +
                       # fma_sun  * ma_sun  +
                       # fmd_moon * md_moon +
                       # fme_moon * me_moon +
                       # fomega   * omega)
          
      # cosine     = cos(fma_moon * ma_moon +
                       # fma_sun  * ma_sun  +
                       # fmd_moon * md_moon +
                       # fme_moon * me_moon +
                       # fomega   * omega)
          
      # delta_psi += (data[i][6].to_f                  + 
                    # data[i][7].to_f  * @ta) * sine +
                    # data[i][10].to_f * cosine
          
      # delta_eps += (data[i][8].to_f                     + 
                    # data[i][9].to_f   * @ta) * cosine +				 
                    # data[i][12].to_f  * sine						
                         
    # end

    
    # delta_eps = delta_eps / 1000.0 / 3600.0
    # delta_psi = delta_psi  / 1000.0 / 3600.0

    [ Celes.nut06a(@ajd, 0)[0], Celes.nut06a(@ajd, 0)[1]]
    # [ nil, nil, ma_moon, ma_sun, md_moon, me_moon, omega]
  end

end
if __FILE__ == $PROGRAM_NAME

  spec = File.expand_path('../../../tests/minitest', __FILE__)
  $LOAD_PATH.unshift(spec) unless $LOAD_PATH.include?(spec)
  require 'nutation_spec'

end