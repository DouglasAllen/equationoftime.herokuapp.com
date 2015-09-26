Wiki 2:

     $ irb --simple-prompt

     require 'eot'
     eot = Eot.new()
     loop do
       puts "#{Time.now} #{eot.show_minutes(eot.now)}"
       sleep 11
     end

Wiki 3:

     latitude,  longitude, date = 41.9474, -88.74467, "2013-12-25"
     require 'eot';eot = Eot.new()
     # set the coordinates manually
     eot.latitude = latitude; eot.longitude = longitude; eot.ajd = Date.parse(date).jd
     eot.ma_ta_set
     eot.sunrise_dt().to_time
     eot.sunset_dt().to_time

Wiki 4:

    require 'eot';eot = Eot.new()
    puts "Show the Local Apparent Sidereal time at the Royal Greenwich Observatory"
     loop do
       eot.ajd = DateTime.now.to_time.utc.to_datetime.ajd
       puts "LST = #{ eot.string_time(((eot.tl_Aries() * Eot::R2D) / 15.0)) }"
       sleep ( 1 - 0.00273790935/1.0027390935) / 1.00273790935
     end

Wiki 5:

     require 'eot';eot = Eot.new()
     "There are #{Eot::SM * 6} hours in a sidereal day."
     "That is why on the next day the stars are about 4 minutes earlier."
     obtime0 = Time.now
     obtime1 = obtime0 + Eot::SM * 6 * 3600
     "Now you know when to look next time."

Wiki 6:

     require 'eot'; eot = Eot.new(); eot.ajd = Date.today.jd.to_f
     DateTime.jd(eot.sunrise_jd + 0.5)
     DateTime.jd(eot.sunset_jd + 0.5)
     
wiki 7:

      require 'eot'; eot = Eot.new(); eot.ajd = Date.today.jd.to_f
      geo = GeoLatLng.new
      geo.addr = "8000 South Michigan Ave., Chicago, IL"
      geo.get_coordinates_from_address
      eot.longitude = geo.lng;eot.latitude = geo.lat
      eot.ajd_to_datetime(eot.sunrise_jd)
      eot.ajd_to_datetime(eot.sunset_jd)
  
