
module EotHelper

  if ENV.fetch("RACK_ENV") == "development"
    p "you're in #{__FILE__}"
  end

  @pi             = Math::PI
  
  @adt            = AnalemmaDataTableHelper::AnalemmaDataTable.new
  @r2d            = Eot::R2D
  @henge          = Eot.new
 
  @henge.latitude = 51.1789
  @henge.longitude= -1.8264
  @henge.ajd      = DateTime.now.to_time.utc.to_datetime.jd.to_f
  
  @geo            = GeoLatLng.new
  @gst            = Eot.new
  @gst.ajd        = DateTime.now.to_time.utc.to_datetime.ajd.to_f
  @gst.ma_ta_set  
  @gst.latitude   = 51.476853
  @gst.longitude  = -0.0005
  @gmst           = @gst.tl_aries / 15.0 * @r2d
  @st             = "The Greenwich Mean Sidereal Time is #{@gst.string_time(@gmst)[0..7]}"
  @eot            = "The Equation of Time is #{@gst.string_eot()}" 
  @utc            = "The time is #{Time.now.utc}"
  @msg            = "Today's sunrise and sunset at the Royal Observatory in Greenwich"
  @rise           = "#{(@henge.sunrise_dt()).to_time.utc}"
  @set            = "#{(@henge.sunset_dt()).to_time.utc}"
  @universal_time = DateTime.now.to_time.utc 
  @year           = @universal_time.year.to_s 
  @month          = @universal_time.month.to_s 
  @day            = @universal_time.day.to_s 
  @date_string    = @year << "-" << @month << "-" << @day
  @current        = @universal_time.to_datetime
  @day_fraction   = @current.day_fraction.to_f
  @solar          = Eot.new
  @solar.ajd      = @current.jd.to_f
  @solar.date     = DateTime.now.to_time.utc.to_date
  @solar.jd       = @solar.date.jd   
  @now            = @solar.ta
  @ma             = @solar.ma_sun()   * @r2d  
  @eqc            = @solar.center()   * @r2d  
  @ta             = @solar.ta_sun()   * @r2d 
  @gml            = @solar.gml_sun()  * @r2d
  @tl             = @solar.tl_sun()   * @r2d  
  @mo             = @solar.mo_earth() * @r2d
  @to             = @solar.to_earth() * @r2d
  @al             = @solar.al_sun()   * @r2d
  @ra             = @solar.ra_sun()   * @r2d  
  @ma_string      = @solar.string_ma_sun()
  @eqc_string     = @solar.string_eqc()
  @tl_string      = @solar.string_tl_sun()
  @ra_string      = @solar.string_ra_sun()
  @et             = @solar.string_eot()
  @s_min          = 4.0 * 360 / 360.98564736629 # 3.989078265
  @e1             = (@ma - @ta) * @s_min

end

class HelpTime
  def page    
    :gmm
  end
  
  def get_time
    Time.now.utc
  end
end
