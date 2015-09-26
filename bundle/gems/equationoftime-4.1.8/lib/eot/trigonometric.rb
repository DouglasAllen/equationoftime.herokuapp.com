# class Eot file = trigometric.rb
# methods using trig functions

class Eot

  # From trigometric.rb:
  # cosine apparent longitude
  # could be useful when dividing
  def cosine_al_sun
    Helio.cos_al_sun(al_sun)
  end
  alias_method :cosine_apparent_longitude, :cosine_al_sun
  alias_method :cosalsun, :cosine_al_sun

  # From trigometric.rb:
  # cosine true longitude
  # used in solar right ascension
  def cosine_tl_sun
    Helio.cos_tl_sun(tl_sun)
  end
  alias_method :cosine_true_longitude, :cosine_tl_sun

  # From trigometric.rb:
  # cosine true obliquity
  # used in solar right ascension and equation of equinox
  def cosine_to_earth
    Helio.cos_to_earth(to_earth)
  end
  alias_method :cosine_true_obliquity, :cosine_to_earth

  # From trigometric.rb:
  # sine apparent longitude
  # used in solar declination
  def sine_al_sun
    Helio.sin_al_sun(al_sun)
  end
  alias_method :sine_apparent_longitude, :sine_al_sun

  # From trigometric.rb:
  # sine true longitude
  # used in solar right ascension
  def sine_tl_sun
    Helio.sin_tl_sun(tl_sun)
  end
  alias_method :sine_true_longitude, :sine_tl_sun

  # From trigometric.rb:
  # sine true obliquity angle of Earth
  # used in solar declination
  def sine_to_earth
    Helio.sin_to_earth(to_earth)
  end
end
