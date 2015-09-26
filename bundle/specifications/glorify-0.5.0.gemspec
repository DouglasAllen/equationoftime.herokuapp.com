# -*- encoding: utf-8 -*-
# stub: glorify 0.5.0 ruby lib

Gem::Specification.new do |s|
  s.name = "glorify"
  s.version = "0.5.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib"]
  s.authors = ["Zachary Scott", "Jonathan Stott", "Simon Gate"]
  s.date = "2013-03-23"
  s.description = "Renders markdown via rdoc-rouge, an RDoc and Rouge bridge. Able to use fenced code blocks like github, and includes a default pygments stylesheet."
  s.email = ["zachary@zacharyscott.net"]
  s.homepage = "http://zacharyscott.net/glorify/"
  s.rubygems_version = "2.4.5"
  s.summary = "Sinatra helper to parse markdown with syntax highlighting like the pros"

  s.installed_by_version = "2.4.5" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<sinatra>, [">= 0"])
      s.add_runtime_dependency(%q<rdoc-rouge>, [">= 0"])
      s.add_runtime_dependency(%q<nokogiri>, [">= 0"])
      s.add_development_dependency(%q<minitest>, [">= 0"])
      s.add_development_dependency(%q<rack-test>, [">= 0"])
      s.add_development_dependency(%q<rake>, [">= 0"])
      s.add_development_dependency(%q<w3c_validators>, [">= 0"])
      s.add_development_dependency(%q<rdoc>, ["= 4.0.0"])
    else
      s.add_dependency(%q<sinatra>, [">= 0"])
      s.add_dependency(%q<rdoc-rouge>, [">= 0"])
      s.add_dependency(%q<nokogiri>, [">= 0"])
      s.add_dependency(%q<minitest>, [">= 0"])
      s.add_dependency(%q<rack-test>, [">= 0"])
      s.add_dependency(%q<rake>, [">= 0"])
      s.add_dependency(%q<w3c_validators>, [">= 0"])
      s.add_dependency(%q<rdoc>, ["= 4.0.0"])
    end
  else
    s.add_dependency(%q<sinatra>, [">= 0"])
    s.add_dependency(%q<rdoc-rouge>, [">= 0"])
    s.add_dependency(%q<nokogiri>, [">= 0"])
    s.add_dependency(%q<minitest>, [">= 0"])
    s.add_dependency(%q<rack-test>, [">= 0"])
    s.add_dependency(%q<rake>, [">= 0"])
    s.add_dependency(%q<w3c_validators>, [">= 0"])
    s.add_dependency(%q<rdoc>, ["= 4.0.0"])
  end
end
