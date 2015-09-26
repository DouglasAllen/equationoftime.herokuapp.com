# -*- encoding: utf-8 -*-
# stub: equationoftime 4.1.8 ruby lib
# stub: ext/eot/extconf.rb

Gem::Specification.new do |s|
  s.name = "equationoftime"
  s.version = "4.1.8"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib"]
  s.authors = ["DouglasAllen"]
  s.date = "2014-11-13"
  s.description = "Calculate Sunrise and Sunset. Uses native C wrappers.\n                        Use the patch \"gem install eot\" to install it."
  s.email = ["kb9agt@gmail.com"]
  s.extensions = ["ext/eot/extconf.rb"]
  s.files = ["ext/eot/extconf.rb"]
  s.homepage = "https://github.com/DouglasAllen/equationoftime"
  s.licenses = ["MIT"]
  s.rdoc_options = ["--title", "Equation of Time -- Solar Position Calculator in Ruby", "--line-numbers"]
  s.rubygems_version = "2.4.5"
  s.summary = "Equation of Time calculates time of solar transition."

  s.installed_by_version = "2.4.5" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<addressable>, ["~> 2.3.6"])
      s.add_runtime_dependency(%q<rest-client>, [">= 0"])
      s.add_runtime_dependency(%q<celes>, ["~> 0.0.1"])
      s.add_development_dependency(%q<bundler>, ["~> 1.7"])
      s.add_development_dependency(%q<rake>, ["~> 10.0"])
    else
      s.add_dependency(%q<addressable>, ["~> 2.3.6"])
      s.add_dependency(%q<rest-client>, [">= 0"])
      s.add_dependency(%q<celes>, ["~> 0.0.1"])
      s.add_dependency(%q<bundler>, ["~> 1.7"])
      s.add_dependency(%q<rake>, ["~> 10.0"])
    end
  else
    s.add_dependency(%q<addressable>, ["~> 2.3.6"])
    s.add_dependency(%q<rest-client>, [">= 0"])
    s.add_dependency(%q<celes>, ["~> 0.0.1"])
    s.add_dependency(%q<bundler>, ["~> 1.7"])
    s.add_dependency(%q<rake>, ["~> 10.0"])
  end
end
