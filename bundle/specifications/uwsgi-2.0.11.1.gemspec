# -*- encoding: utf-8 -*-
# stub: uwsgi 2.0.11.1 ruby .
# stub: ext/uwsgi/extconf.rb

Gem::Specification.new do |s|
  s.name = "uwsgi"
  s.version = "2.0.11.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.require_paths = ["."]
  s.authors = ["Unbit"]
  s.date = "2015-07-19"
  s.description = "The uWSGI server for Ruby/Rack"
  s.email = "info@unbit.it"
  s.executables = ["uwsgi"]
  s.extensions = ["ext/uwsgi/extconf.rb"]
  s.files = ["bin/uwsgi", "ext/uwsgi/extconf.rb"]
  s.homepage = "http://projects.unbit.it/uwsgi"
  s.licenses = ["GPL-2"]
  s.rubygems_version = "2.4.5"
  s.summary = "uWSGI"

  s.installed_by_version = "2.4.5" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<rack>, [">= 0"])
    else
      s.add_dependency(%q<rack>, [">= 0"])
    end
  else
    s.add_dependency(%q<rack>, [">= 0"])
  end
end
