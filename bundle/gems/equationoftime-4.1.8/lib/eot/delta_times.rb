# class Eot file = delta_times.rb
# methods converting delta angles to time
class Eot
  # From delta_times.rb:
  # Uses @ajd attribute
  # Returns Oblique component of EOT in decimal minutes time
  def time_delta_oblique
    delta_oblique * R2D * SM
  end

  # From delta_times.rb:
  # Uses @ajd attribute
  # Returns Orbit component of EOT in decimal minutes time
  def time_delta_orbit
    delta_orbit * R2D * SM
  end

  # From delta_times.rb:
  # Uses @ajd attribute
  # Returns EOT as a float for decimal minutes time
  def time_eot
    eot * R2D * SM
  end
end
