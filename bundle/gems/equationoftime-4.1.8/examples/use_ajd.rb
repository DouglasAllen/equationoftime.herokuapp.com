require 'eot'
eot = Eot.new
heredoc = <<HD
Setting the ajd sets a lot of other attributes.
All the angle calculations use this one setting.
ex: eot.ajd = 2451545.0
#{eot.ajd = 2_451_545.0}
You may get just about any value now from
various methods.
ex: eot.eot
#{eot.eot} radians
What day was that ajd?
eot.ajd_to_datetime(eot.ajd)
#{eot.ajd_to_datetime(eot.ajd)}
Sun apparent longitude.
eot.al_sun
#{eot.al_sun} radians
Try adding 80 days to the ajd
eot.ajd = 2451545.0 + 78
#{eot.ajd = 2_451_545.0 + 78}
#{eot.al_sun} radians
Almost a full circle in radians.
What day is that?
eot.ajd_to_datetime(eot.ajd)
#{eot.ajd_to_datetime(eot.ajd)}
That's near the Vernal Exquinox.
It nomally occurs 78 days after the Earth is
in perihelion of it's orbit around the Sun.
When does perihelion occur then?
A reasonable estimate is about the 3rd day of a new year.
eot.ajd = 2451545.0 + 2
#{eot.ajd = 2_451_545.0 + 2}
Now add the 78 days.
eot.ajd + 78
#{eot.ajd += 78}
#{eot.al_sun} radians
We completed the orbit plus a little extra.
It's just a rough estimate and is always changing.
HD
puts heredoc
