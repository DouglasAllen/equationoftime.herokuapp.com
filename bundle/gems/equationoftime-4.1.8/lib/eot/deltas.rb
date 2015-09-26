# class Eot file = deltas.rb
# methods for angle deltas
class Eot
  # From deltas.rb:
  # delta epsilon
  # component of equation of equinox
  def angle_delta_epsilon
    Celes.nut06a(@ajd, 0)[1]
  end
  alias_method :delta_epsilon, :angle_delta_epsilon

  # From deltas.rb:
  # one time component to total equation of time
  def angle_delta_oblique
    al_sun - ra_sun
  end
  alias_method :delta_t_ecliptic, :angle_delta_oblique
  alias_method :delta_oblique, :angle_delta_oblique

  # From angles.rb:
  # one time component to total equation of time
  def angle_delta_orbit
    -1.0 * Helio.eqc(@ma, @ta)
  end
  alias_method :delta_t_elliptic, :angle_delta_orbit
  alias_method :delta_orbit, :angle_delta_orbit

  # From angles.rb:
  # component of equation of equinox
  def angle_delta_psi
    Celes.nut06a(@ajd, 0)[0]
  end
  alias_method :delta_psi, :angle_delta_psi

  # From angles.rb:
  # total equation of time
  def angle_equation_of_time
    delta_orbit + delta_oblique
  end
  alias_method :eot, :angle_equation_of_time
end
