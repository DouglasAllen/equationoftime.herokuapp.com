require 'eot'
eot = Eot.new
geo = GeoLatLng.new
heredoc = <<HD
The default address is '#{eot.addr}' as a string.
It is concantenated to the GeoLatLng base address
Create an instance of GeoLatLng with new method
ex: geo = GeoLatLng.new
examine the base address geo.base_json
#{geo.base_json}
This is used to lookup your coordinates using Google
maps. Use geo.set_coordinates.
#{geo.set_coordinates}
Just change the address to any desired location.
Use comma or space seperated terms.
ex: "huston, tx"
#{geo.addr = 'huston, tx'}
#{geo.set_coordinates}
HD
puts heredoc
