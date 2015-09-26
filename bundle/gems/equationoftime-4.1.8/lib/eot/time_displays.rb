# class Eot file = time_displays.rb
# methods for time displays
class Eot
  # From displays.rb
  # String formatter for + and - time
  def show_minutes(min = 0.0)
    min.nil? ? min = 0.0 : min
    time = Time.utc(1, 1, 1, 0, 0, 0, 0.0)
    time += (min.abs * 60.0)
    sign = sign_min(min)
    time.strftime("#{sign}%M:%S.%3N")
  end

  # From displays.rb
  # String for time now
  def show_now(now = now(Time.now.utc))
    show_minutes(now)
  end

  # From displays.rb
  # String formatter for fraction of Julian day number
  def string_day_fraction_to_time(jpd_time = 0.0)
    jpd_time.nil? ? jpd_time = 0.0 : jpd_time
    fraction = jpd_time + 0.5 - Integer(jpd_time)
    h = Integer(fraction * DAY_HOURS)
    m = Integer((fraction - h / DAY_HOURS) * DAY_MINUTES)
    s = Integer((fraction - h / 24.0 - m / DAY_MINUTES) * DAY_SECONDS)
    format('%02d:', h) +
    # ':' +
    format('%02d', m) +
                  ':' +
    format('%02d', s)
  end
  alias_method :julian_period_day_fraction_to_time, :string_day_fraction_to_time

  # From displays.rb
  # radians to time method
  def string_deg_to_time(radians = 0.0)
    radians.nil? ? radians = 0.0 : radians
    s, ihmsf = Celes.a2tf(3, radians)
    f_string(s, ihmsf[0], ihmsf[1], ihmsf[2], ihmsf[3])
  end

  # From displays.rb
  # displays + or - sign
  def sign_min(min)
    if min < 0.0
      sign = '-'
    else
      sign = '+'
    end
    sign
  end

  # From displays.rb
  # Equation of time output for minutes and seconds
  def string_eot
    min_eot = time_eot
    sign = sign_min(min_eot)
    eot = min_eot.abs
    minutes = Integer(eot)
    seconds = (eot - minutes) * 60.0
    decimal_seconds = (seconds - Integer(seconds)) * 100.0
    min = format('%02d', minutes)
    sec = format('%02d', seconds)
    dec_sec = format('%01d', decimal_seconds)
    sign << min << 'm, ' << sec << '.' << dec_sec << 's'
  end
  alias_method :display_equation_of_time, :string_eot

  # From displays.rb
  # String format conversion of jd to date
  def string_jd_to_date(jd = DJ00)
    jd = check_jd_zero(jd)
    Date.jd(jd).to_s
  end
  alias_method :jd_to_date_string, :string_jd_to_date

  # From displays.rb
  # formats time components
  def format_time(h, m, s, ds)
    format('%02d', h)   +
                 ':' +
    format('%02d', m) +
                 ':' +
    format('%02d', s) +
                 '.' +
    format('%3.3d', ds)
  end

  # From displays.rb
  # creates [h,m,s,ds] array from Time or DateTime
  def dt_parts(val)
    h  = val.hour
    m  = val.min
    s  = val.sec
    is = Integer(s)
    ds = Integer((s - is).round(3) * 1000.0)
    [h, m, is, ds]
  end

  # From displays.rb
  # creates [h,m,s,ds] from hours Float 
  def float_parts(val)
    hours = Integer(val % DAY_HOURS)
    mins = 60.0 * (val % DAY_HOURS - hours)
    imins = Integer(mins)
    secs = 60.0 * (mins - imins)
    isecs = Integer(secs)
    ds    = Integer((secs - isecs).round(3) * 1000.0)
    [hours, imins, isecs, ds]
  end

  # From displays.rb
  # String formatter for h:m:s display
  def string_time(dt = DT2000)
    dt = check_t_zero(dt)
    dt.class == DateTime ? ta = dt_parts(dt) : ta = float_parts(dt)
    format_time(ta[0], ta[1], ta[2], ta[3])
  end
  alias_method :display_time_string, :string_time
end
