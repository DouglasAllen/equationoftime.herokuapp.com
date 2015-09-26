require 'celes'
require 'date'
p d = DateTime.now.to_time.utc.to_datetime
djm0, djm = Celes::cal2jd(d.year, d.month, d.day + d.day_fraction)
p djm0
p djm
p djm + djm0
p d.ajd.to_f
p d.day_fraction.to_f
p (d.ajd - d.day_fraction).to_f
