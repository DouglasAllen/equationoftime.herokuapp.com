require 'eot'
eot = Eot.new
puts "My Longitude: #{eot.longitude = -75.324}"
puts "The current UTC noon as ajd: #{eot.ajd}"
puts "My mean local noon as ajd  : #{eot.mean_local_noon_jd}"
puts "My true local noon as ajd  : #{eot.local_noon_dt.ajd.to_f}"
eot_jd = eot.mean_local_noon_jd - eot.local_noon_dt.ajd
puts "Note: ajd and jd decimals only go so far and so slight difference here"
puts "and obviously some rounding occurs when looking at the second ajd above."
puts "mean - true: #{e1 = eot_jd}"
puts "eot.eot_jd : #{e2 = eot.eot_jd}"
puts "The differnce: #{e1 - e2}"
puts "which in minutes is: #{1440.0 * (e1 - e2)}"
puts "and in arc minutes is: #{15.0 * 1440.0 * (e1 - e2)}"