# -*- encoding: utf-8 -*-
# stub: config 1.0.0 ruby lib

Gem::Specification.new do |s|
  s.name = "config"
  s.version = "1.0.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib"]
  s.authors = ["Jacques Crocker", "Fred Wu", "Piotr Kuczynski"]
  s.date = "2015-08-10"
  s.description = "Easiest way to add multi-environment yaml settings to Rails, Sinatra, Pandrino and other ruby projects."
  s.email = ["railsjedi@gmail.com", "ifredwu@gmail.com", "piotr.kuczynski@gmail.com"]
  s.extra_rdoc_files = ["README.md"]
  s.files = ["README.md"]
  s.homepage = "https://github.com/railsconfig/config"
  s.licenses = ["MIT"]
  s.rdoc_options = ["--charset=UTF-8"]
  s.rubygems_version = "2.4.5"
  s.summary = "Easiest way to add multi-environment yaml settings to Rails, Sinatra, Pandrino and other ruby projects."

  s.installed_by_version = "2.4.5" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<activesupport>, [">= 3.0"])
      s.add_runtime_dependency(%q<deep_merge>, ["~> 1.0.0"])
      s.add_development_dependency(%q<bundler>, ["~> 1.10.5"])
      s.add_development_dependency(%q<rake>, [">= 0"])
      s.add_development_dependency(%q<rdoc>, [">= 0"])
      s.add_development_dependency(%q<pry>, [">= 0"])
      s.add_development_dependency(%q<appraisal>, ["~> 2.0.2"])
      s.add_development_dependency(%q<rails>, ["~> 4.2.3"])
      s.add_development_dependency(%q<rspec>, ["~> 3.3.0"])
      s.add_development_dependency(%q<rspec-rails>, ["~> 3.3.3"])
      s.add_development_dependency(%q<test-unit>, ["~> 3.1.3"])
      s.add_development_dependency(%q<sqlite3>, [">= 0"])
      s.add_development_dependency(%q<rubocop>, [">= 0"])
    else
      s.add_dependency(%q<activesupport>, [">= 3.0"])
      s.add_dependency(%q<deep_merge>, ["~> 1.0.0"])
      s.add_dependency(%q<bundler>, ["~> 1.10.5"])
      s.add_dependency(%q<rake>, [">= 0"])
      s.add_dependency(%q<rdoc>, [">= 0"])
      s.add_dependency(%q<pry>, [">= 0"])
      s.add_dependency(%q<appraisal>, ["~> 2.0.2"])
      s.add_dependency(%q<rails>, ["~> 4.2.3"])
      s.add_dependency(%q<rspec>, ["~> 3.3.0"])
      s.add_dependency(%q<rspec-rails>, ["~> 3.3.3"])
      s.add_dependency(%q<test-unit>, ["~> 3.1.3"])
      s.add_dependency(%q<sqlite3>, [">= 0"])
      s.add_dependency(%q<rubocop>, [">= 0"])
    end
  else
    s.add_dependency(%q<activesupport>, [">= 3.0"])
    s.add_dependency(%q<deep_merge>, ["~> 1.0.0"])
    s.add_dependency(%q<bundler>, ["~> 1.10.5"])
    s.add_dependency(%q<rake>, [">= 0"])
    s.add_dependency(%q<rdoc>, [">= 0"])
    s.add_dependency(%q<pry>, [">= 0"])
    s.add_dependency(%q<appraisal>, ["~> 2.0.2"])
    s.add_dependency(%q<rails>, ["~> 4.2.3"])
    s.add_dependency(%q<rspec>, ["~> 3.3.0"])
    s.add_dependency(%q<rspec-rails>, ["~> 3.3.3"])
    s.add_dependency(%q<test-unit>, ["~> 3.1.3"])
    s.add_dependency(%q<sqlite3>, [">= 0"])
    s.add_dependency(%q<rubocop>, [">= 0"])
  end
end
