# -*- encoding: utf-8 -*-
# stub: rack-pygmentize 1.0.1 ruby lib

Gem::Specification.new do |s|
  s.name = "rack-pygmentize"
  s.version = "1.0.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib"]
  s.authors = ["Lee Jarvis"]
  s.date = "2011-03-15"
  s.description = "Rack middleware used to automagically format your code blocks using pygmentize"
  s.email = ["lee@jarvis.co"]
  s.homepage = "http://github.com/injekt/rack-pygmentize"
  s.rubygems_version = "2.4.5"
  s.summary = "Rack middleware to pygmentize your code blocks"

  s.installed_by_version = "2.4.5" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<rack>, [">= 1.0.0"])
      s.add_runtime_dependency(%q<nokogiri>, [">= 1.4.4"])
      s.add_runtime_dependency(%q<albino>, [">= 1.3.2"])
    else
      s.add_dependency(%q<rack>, [">= 1.0.0"])
      s.add_dependency(%q<nokogiri>, [">= 1.4.4"])
      s.add_dependency(%q<albino>, [">= 1.3.2"])
    end
  else
    s.add_dependency(%q<rack>, [">= 1.0.0"])
    s.add_dependency(%q<nokogiri>, [">= 1.4.4"])
    s.add_dependency(%q<albino>, [">= 1.3.2"])
  end
end
