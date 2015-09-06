# -*- encoding: utf-8 -*-
# stub: rack-codehighlighter 0.5.1 ruby lib

Gem::Specification.new do |s|
  s.name = "rack-codehighlighter"
  s.version = "0.5.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib"]
  s.authors = ["W\u{142}odek Bzyl"]
  s.date = "2015-08-25"
  s.description = "Rack Middleware for Code Highlighting. Supports the most popular Ruby code highlighters."
  s.email = ["matwb@ug.edu.pl"]
  s.homepage = "http://tao.inf.ug.edu.pl/"
  s.rubygems_version = "2.4.5"
  s.summary = "Rack Middleware for Code Highlighting."

  s.installed_by_version = "2.4.5" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<rack>, [">= 1.0.0"])
      s.add_runtime_dependency(%q<nokogiri>, [">= 1.4.1"])
    else
      s.add_dependency(%q<rack>, [">= 1.0.0"])
      s.add_dependency(%q<nokogiri>, [">= 1.4.1"])
    end
  else
    s.add_dependency(%q<rack>, [">= 1.0.0"])
    s.add_dependency(%q<nokogiri>, [">= 1.4.1"])
  end
end
