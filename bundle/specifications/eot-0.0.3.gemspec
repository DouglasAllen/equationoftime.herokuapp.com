# -*- encoding: utf-8 -*-
# stub: eot 0.0.3 ruby lib

Gem::Specification.new do |s|
  s.name = "eot"
  s.version = "0.0.3"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib"]
  s.authors = ["Douglas Allen"]
  s.date = "2015-04-09"
  s.description = "$eot +-lat +-lng YYYY-MM-DD"
  s.email = ["kb9agt@gmail.com"]
  s.executables = ["eot"]
  s.files = ["bin/eot"]
  s.homepage = "https://github.com/DouglasAllen/eot"
  s.licenses = ["MIT"]
  s.rubygems_version = "2.4.5"
  s.summary = "bin runner and installer"

  s.installed_by_version = "2.4.5" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_development_dependency(%q<bundler>, ["~> 1.7"])
      s.add_development_dependency(%q<rake>, ["~> 10.0"])
      s.add_runtime_dependency(%q<celes>, [">= 0"])
      s.add_runtime_dependency(%q<equationoftime>, [">= 0"])
    else
      s.add_dependency(%q<bundler>, ["~> 1.7"])
      s.add_dependency(%q<rake>, ["~> 10.0"])
      s.add_dependency(%q<celes>, [">= 0"])
      s.add_dependency(%q<equationoftime>, [">= 0"])
    end
  else
    s.add_dependency(%q<bundler>, ["~> 1.7"])
    s.add_dependency(%q<rake>, ["~> 10.0"])
    s.add_dependency(%q<celes>, [">= 0"])
    s.add_dependency(%q<equationoftime>, [">= 0"])
  end
end
