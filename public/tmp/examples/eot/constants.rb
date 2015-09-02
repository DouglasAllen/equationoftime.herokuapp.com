# constants.rb

require 'date'

class Eot
  
  # Array result for time_julian_century default = [0.0, 0.0, 0.0, 0.0, 0.0]    
  # A2000       = [0.0, 0.0, 0.0, 0.0, 0.0] 

  # Arc seconds in a degree = 3_600.0  
  ARCSEC      = 3_600.0
  
  # Arc seconds in a degree = 3_600.0  
  ASD         = 3_600.0
  
  # Arc seconds in an hour = 240.0
  # ASH         = 240.0
  
  # Light time for 1 au (s) = 499.004782
  # AULT        = 499.004782

  # Speed of light (m/s) = 299792458.0
  # CMPS        = 299792458.0  

  # Default date string = "2000-01-01"  
  # D2000       = "2000-01-01"

  # 2Pi = 6.283185307179586476925287 
  # D2PI        = 6.283185307179586476925287  

  # from desktop calculator DAS2R = 4.8481368110953599358991410235795e-6
  DAS2R       = 4.8481368110953599358991410235795e-6

  # Astronomical unit (m) = 149597870e3
  # DAU         = 149597870e3  

  # Hours in a day = 24.0  
  DAY_HOURS   = 24.0 
  
  # Minutes in a day = 1_440.0  
  DAY_MINUTES = 1_440.0 

  # Seconds in a day = 86_400.0  
  DAY_SECONDS = 86_400.0
  
  # Seconds in a day = 86_400.0
  DAYSEC      = 86400.0  

  # Micro Seconds in a day = 86_400_000_000.0  
  DAY_USECS   = 86_400_000_000.0
  
  # Speed of light (AU per day) = DAYSEC / AULT
  # DC = DAYSEC / AULT
  
  # from desktop calculator D2R = 0.017453292519943295769236907684886
  D2R          = 0.017453292519943295769236907684886
  
  # dint(A) - truncate to nearest whole number towards zero (double) 
  # dint(A) = ((A)<0.0?ceil(A):floor(A))

  # dnint(A) - round to nearest whole number (double) 
  # dnint(A) = ((A)<0.0?ceil((A)-0.5):floor((A)+0.5))

  # dsign(A,B) - magnitude of A with sign of B (double) 
  # dsign(A,B) = ((B)<0.0?-fabs(A):fabs(A))
  
  # Reference epoch (J2000.0), Julian Date
  # Default Julian Number = 2451545.0  
  DJ00        = 2451545.0  
  
  # Days per Julian century = 36525.0 
  DJC         = 36525.0
  
  # Days per Julian millennium  = 365250.0
  # DJM         = 365250.0

  # Julian Date of Modified Julian Date zero
  # 1858, 11, 17, 0.0 midnight start of calendar reform = 2400000.5
  # Removed from Julian Date to get Modified Julian Date
  # DJM0        = 2400000.5  

  # Reference epoch (J2000.0), Modified Julian Date = 51544.5  
  # DJM00       = 51544.5

  # 1977 Jan 1.0 as MJD = 43144.0  
  # DJM77       = 43144.0  
  
  # Days per Julian year = 365.25 
  # DJY         = 365.25
  
  # Milli-arc-seconds to radians  = DAS2R / 1e3
  # DMAS2R      = DAS2R / 1e3
  
  # Radians to arc seconds = 206264.8062470963551564734 
  # DR2AS       = 206264.8062470963551564734    
  
  # Seconds of time to radians = 7.272205216643039903848712e-5 
  # DS2R        = 7.272205216643039903848712e-5

  # Default DateTime = DateTime.new( 2000, 01, 01, 12, 00, 00, "+00:00" )  
  DT2000      = DateTime.new( 2000, 01, 01, 12, 00, 00, "+00:00" )    

  # arc seconds degrees to radians = PI / 180.0 / ARCSEC  
  # DTR         = PI / 180.0 / ARCSEC
  # DTR         = 4.8481368110953599358991410235795e-6 # from calculator  
  
  # Length of tropical year B1900 (days) = 365.242198781 
  # DTY         = 365.242198781

  # L_G = 1 - d(TT)/d(TCG) = 6.969290134e-10
  # ELG         = 6.969290134e-10

  # L_B = 1 - d(TDB)/d(TCB)  = 1.550519768e-8 
  # ELB         = 1.550519768e-8  

  # max(A,B) - larger (most +ve) of two numbers (generic) 
  # gmax(A,B) = (((A)>(B))?(A):(B))

  # min(A,B) - smaller (least +ve) of two numbers (generic) 
  # gmin(A,B) = (((A)<(B))?(A):(B))  

  # Reference epoch (J2000.0), Julian Date
  # Default Julian Number = 2451545.0  
  # J2000       = 2451545.0  
  
  # Julian Date of Modified Julian Date zero
  # 1858, 11, 17, 0.0 midnight start of calendar reform = 2400000.5  
  # MJD0        = 2400000.5
  
  # 2Pi from Math module = Math::PI * 2.0
  # P2          = PI * 2.0

  # from desktop calculator PI = 3.1415926535897932384626433832795
  PI          = 3.1415926535897932384626433832795   
  
  # from desktop calculator R2D = 57.295779513082320876798154814105
  R2D         = 57.295779513082320876798154814105
  
  # from desktop calculator RTD = 0.015915494309189533576888376337251
  RTD         = 0.015915494309189533576888376337251 
  
  # from desktop calculator Sidereal minutes = 4.0 / 1.0027379093507953456536618754278
  SM          = 4.0 / 1.0027379093507953456536618754278
  
  # Schwarzschild radius of the Sun (au) = 2 * 1.32712440041e20 / (2.99792458e8)^2 / 1.49597870700e11 
  # SRS         = 1.97412574336e-8
  
  # TDB (s) at TAI 1977/1/1.0 = -6.55e-5
  # TDB0        = -6.55e-5  

  # TT minus TAI (s) = 32.184
  # TTMTAI      = 32.184

  # Arcseconds in a full circle  = 1296000.0 
  # TURNAS      = 1296000.0  
  
end

if __FILE__ == $PROGRAM_NAME

  spec = File.expand_path('../../../tests/minitest', __FILE__)
  $LOAD_PATH.unshift(spec) unless $LOAD_PATH.include?(spec)
  require 'constants_spec'

end