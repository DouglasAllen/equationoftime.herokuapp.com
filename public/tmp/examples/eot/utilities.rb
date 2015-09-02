# utilities.rb

class Eot
  # From utilities.rb:<br>
  # A check for default J2000
  # sets default when arg is nil
  def check_jd_nil( jd = DJ00 )
    jd.nil? ? jd = DJ00 : jd
  end

  # From utilities.rb:<br>
  # A check for default J2000
  # sets default when arg is zero
  def check_jd_zero( jd = DJ00 )
    jd == 0 ? jd = DJ00 : jd = check_jd_nil( jd )
  end

  # From utilities.rb:<br>
  # A check for default DT2000
  # sets default when arg is nil
  def check_t_nil( dt = DT2000 )
    dt.nil? ? dt = DT2000 : dt
  end

  # From utilities.rb:<br>
  # A check for default DT2000
  # sets default when arg is zero
  def check_t_zero( dt = DT2000 )
    dt == 0 ? dt = DT2000 : dt = check_t_nil( dt )
  end

  # From utilities.rb:<br>
  # Keeps large angles in range of 360.0
  # aliased by truncate
  def mod_360( x = 0.0 )
    x.nil? ? x = 0.0 : x
    360.0 * ( x / 360.0 - Integer( x / 360.0 ) )
  end
  alias_method :truncate, :mod_360

end

if __FILE__ == $PROGRAM_NAME

  spec = File.expand_path('../../../tests/minitest', __FILE__)
  $LOAD_PATH.unshift(spec) unless $LOAD_PATH.include?(spec)
  require 'utilities_spec'
  require 'aliased_utilities_spec'

end