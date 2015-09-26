# -*- encoding: utf-8 -*-
# stub: textacular 3.2.2 ruby lib

Gem::Specification.new do |s|
  s.name = "textacular"
  s.version = "3.2.2"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib"]
  s.authors = ["Ben Hamill", "ecin", "Aaron Patterson", "Greg Molnar"]
  s.date = "2015-03-28"
  s.description = "Textacular exposes full text search capabilities from PostgreSQL, extending\n    ActiveRecord with scopes making search easy and fun!"
  s.email = ["git-commits@benhamill.com", "ecin@copypastel.com"]
  s.homepage = "http://textacular.github.com/textacular"
  s.licenses = ["MIT"]
  s.rubygems_version = "2.4.5"
  s.summary = "Textacular exposes full text search capabilities from PostgreSQL"

  s.installed_by_version = "2.4.5" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_development_dependency(%q<pg>, ["~> 0.14"])
      s.add_development_dependency(%q<rspec>, [">= 0"])
      s.add_development_dependency(%q<database_cleaner>, [">= 0"])
      s.add_development_dependency(%q<rake>, [">= 0"])
      s.add_development_dependency(%q<pry>, [">= 0"])
      s.add_development_dependency(%q<pry-doc>, [">= 0"])
      s.add_runtime_dependency(%q<activerecord>, ["< 5.0", ">= 3.0"])
    else
      s.add_dependency(%q<pg>, ["~> 0.14"])
      s.add_dependency(%q<rspec>, [">= 0"])
      s.add_dependency(%q<database_cleaner>, [">= 0"])
      s.add_dependency(%q<rake>, [">= 0"])
      s.add_dependency(%q<pry>, [">= 0"])
      s.add_dependency(%q<pry-doc>, [">= 0"])
      s.add_dependency(%q<activerecord>, ["< 5.0", ">= 3.0"])
    end
  else
    s.add_dependency(%q<pg>, ["~> 0.14"])
    s.add_dependency(%q<rspec>, [">= 0"])
    s.add_dependency(%q<database_cleaner>, [">= 0"])
    s.add_dependency(%q<rake>, [">= 0"])
    s.add_dependency(%q<pry>, [">= 0"])
    s.add_dependency(%q<pry-doc>, [">= 0"])
    s.add_dependency(%q<activerecord>, ["< 5.0", ">= 3.0"])
  end
end
