# -*- encoding: utf-8 -*-
# stub: rack-highlighter 0.2.1 ruby lib

Gem::Specification.new do |s|
  s.name = "rack-highlighter"
  s.version = "0.2.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib"]
  s.authors = ["Daniel Perez Alvarez"]
  s.date = "2013-08-23"
  s.description = "Rack Middleware for syntax highlighting."
  s.email = ["unindented@gmail.com"]
  s.homepage = "http://github.com/unindented/rack-highlighter"
  s.required_ruby_version = Gem::Requirement.new(">= 1.9.0")
  s.rubygems_version = "2.4.5"
  s.summary = "Rack Middleware that provides syntax highlighting of code blocks, using CodeRay, Pygments or Ultraviolet."

  s.installed_by_version = "2.4.5" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<rack>, [">= 1.0.0"])
      s.add_runtime_dependency(%q<nokogiri>, [">= 1.4.0"])
      s.add_runtime_dependency(%q<htmlentities>, [">= 4.0.0"])
      s.add_development_dependency(%q<coderay>, ["~> 1.0"])
      s.add_development_dependency(%q<pygments.rb>, ["~> 0.5"])
      s.add_development_dependency(%q<rouge>, ["~> 0.3"])
      s.add_development_dependency(%q<ultraviolet>, ["~> 1.0"])
      s.add_development_dependency(%q<rake>, [">= 0"])
      s.add_development_dependency(%q<minitest>, [">= 0"])
      s.add_development_dependency(%q<minitest-reporters>, [">= 0"])
      s.add_development_dependency(%q<rack-test>, [">= 0"])
      s.add_development_dependency(%q<guard-minitest>, [">= 0"])
      s.add_development_dependency(%q<rb-inotify>, [">= 0"])
      s.add_development_dependency(%q<rb-fsevent>, [">= 0"])
      s.add_development_dependency(%q<rb-fchange>, [">= 0"])
    else
      s.add_dependency(%q<rack>, [">= 1.0.0"])
      s.add_dependency(%q<nokogiri>, [">= 1.4.0"])
      s.add_dependency(%q<htmlentities>, [">= 4.0.0"])
      s.add_dependency(%q<coderay>, ["~> 1.0"])
      s.add_dependency(%q<pygments.rb>, ["~> 0.5"])
      s.add_dependency(%q<rouge>, ["~> 0.3"])
      s.add_dependency(%q<ultraviolet>, ["~> 1.0"])
      s.add_dependency(%q<rake>, [">= 0"])
      s.add_dependency(%q<minitest>, [">= 0"])
      s.add_dependency(%q<minitest-reporters>, [">= 0"])
      s.add_dependency(%q<rack-test>, [">= 0"])
      s.add_dependency(%q<guard-minitest>, [">= 0"])
      s.add_dependency(%q<rb-inotify>, [">= 0"])
      s.add_dependency(%q<rb-fsevent>, [">= 0"])
      s.add_dependency(%q<rb-fchange>, [">= 0"])
    end
  else
    s.add_dependency(%q<rack>, [">= 1.0.0"])
    s.add_dependency(%q<nokogiri>, [">= 1.4.0"])
    s.add_dependency(%q<htmlentities>, [">= 4.0.0"])
    s.add_dependency(%q<coderay>, ["~> 1.0"])
    s.add_dependency(%q<pygments.rb>, ["~> 0.5"])
    s.add_dependency(%q<rouge>, ["~> 0.3"])
    s.add_dependency(%q<ultraviolet>, ["~> 1.0"])
    s.add_dependency(%q<rake>, [">= 0"])
    s.add_dependency(%q<minitest>, [">= 0"])
    s.add_dependency(%q<minitest-reporters>, [">= 0"])
    s.add_dependency(%q<rack-test>, [">= 0"])
    s.add_dependency(%q<guard-minitest>, [">= 0"])
    s.add_dependency(%q<rb-inotify>, [">= 0"])
    s.add_dependency(%q<rb-fsevent>, [">= 0"])
    s.add_dependency(%q<rb-fchange>, [">= 0"])
  end
end
