# -*- encoding: utf-8 -*-
# stub: rygments 0.2.0 ruby lib
# stub: ext/extconf.rb

Gem::Specification.new do |s|
  s.name = "rygments"
  s.version = "0.2.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib"]
  s.authors = ["Emil Loer"]
  s.date = "2011-03-01"
  s.description = "Rygments is a Ruby wrapper for the Pygments syntax highlighter. It uses an embedded Python interpreter to get high processing throughput."
  s.email = ["emil@koffietijd.net"]
  s.extensions = ["ext/extconf.rb"]
  s.files = ["ext/extconf.rb"]
  s.homepage = "https://github.com/thedjinn/rygments"
  s.rubyforge_project = "rygments"
  s.rubygems_version = "2.4.5"
  s.summary = "Rygments is a Ruby wrapper for Pygments"

  s.installed_by_version = "2.4.5" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_development_dependency(%q<rspec>, ["~> 2.0"])
      s.add_development_dependency(%q<rake-compiler>, ["~> 0.7"])
    else
      s.add_dependency(%q<rspec>, ["~> 2.0"])
      s.add_dependency(%q<rake-compiler>, ["~> 0.7"])
    end
  else
    s.add_dependency(%q<rspec>, ["~> 2.0"])
    s.add_dependency(%q<rake-compiler>, ["~> 0.7"])
  end
end
