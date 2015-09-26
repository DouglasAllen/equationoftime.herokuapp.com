lib = File.expand_path('../../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'eot'

eot = Eot.new

p eot.ajd
p eot.ta # set on initializating using ajd
p eot.ma # set on initializating using ajd
# new date used
p ajd = DateTime.new(2000, 1, 1).jd
eot.ajd = ajd
eot.ma_ta_set # this sets the attributes
p ta = eot.ta # now these would be different
p ma = eot.ma # now these would be different
p ta_m = eot.eqc(ma, ta)
p om = eot.omega
p eot.al(ma, ta, om)
p eot.sun_dec(eot.al(ma, ta, om), eot.to_earth)
p eot.eoe(ta)
p eot.ml(ta)
p eot.era
p eot.tl_aries
