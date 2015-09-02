# vars.rb

class Equation_of_Time
  
  # gets attribute ajd  
  # in vars.rb    
  def get_ajd      
    @ajd
  end
  
  # gets attribute data  
  # in vars.rb      
  def get_data
    @data
  end 

  # gets attribute date  
  # in vars.rb     
  def get_date      
    @date
  end 

  # gets attribute jd  
  # in vars.rb      
  def get_jd
    @jd
  end

  # gets attribute latitude 
  # in vars.rb      
  def get_latitude
    @latitude
  end 

  # gets attribute longitude  
  # in vars.rb      
  def get_longitude
    @longitude
  end

  # sets attribute ajd   
  # in vars.rb  
  def set_ajd( ajd = nil )      
    @ajd = ajd
  end  
  
  # sets attribute date  
  # in vars.rb      	
  def set_date( date = D2000 )      
    date = check_date_zero( date )      
    @date = Date.parse( date ).to_time.utc
  end
  
  # sets attribute jd  
  # in vars.rb     
  def set_jd( jd = nil )      
    @jd = jd
  end
  
  # sets attribute latitude
  # in vars.rb   
  def set_latitude( latitude = nil )
    @latitude = latitude.to_f
  end
  
  # sets attribute longitude
  # in vars.rb  
  def set_longitude( longitude = nil )
    @longitude = longitude.to_f
  end

end   	
if __FILE__ == $PROGRAM_NAME
end