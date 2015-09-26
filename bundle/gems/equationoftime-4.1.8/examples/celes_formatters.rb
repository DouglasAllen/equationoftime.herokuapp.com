require 'celes'

puts '3 decimal places for 2.345 radians in'
s, idmsf = Celes.a2af(3, 2.345)
p s
p idmsf

puts '3 decimal places for -3.01234 radians in'
s, ihmsf = Celes.a2tf(3, -3.01234)
p s
p ihmsf

puts 'formatted -45:13:27.2 degrees in'
a = Celes.af2a('-', 45, 13, 27.2, &a)
p a

puts 'normalize range 0-2pi radians'
a = Celes.anp(-0.1)
p a

puts 'normalize range -pi-+pi radians'
a = Celes.anpm(-4.0)
p a
