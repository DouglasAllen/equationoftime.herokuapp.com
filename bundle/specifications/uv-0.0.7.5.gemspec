# -*- encoding: utf-8 -*-
# stub: uv 0.0.7.5 ruby lib

Gem::Specification.new do |s|
  s.name = "uv"
  s.version = "0.0.7.5"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib"]
  s.authors = ["spox", "chaffeqa"]
  s.date = "2011-10-04"
  s.description = "Ruby powered syntax highlighting.  Ruby 1.9 port of Ultraviolet"
  s.email = ["spox@modspox.com", "chaffeqa@gmail.com"]
  s.executables = ["theme2latexrender", "theme2xhtmlrender", "uv"]
  s.files = ["bin/theme2latexrender", "bin/theme2xhtmlrender", "bin/uv"]
  s.homepage = "https://github.com/chaffeqa/uv"
  s.required_ruby_version = Gem::Requirement.new(">= 1.9.0")
  s.rubyforge_project = "uv"
  s.rubygems_version = "2.4.5"
  s.summary = "ultraviolet in ruby 1.9+"

  s.installed_by_version = "2.4.5" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<spox-textpow>, [">= 0"])
      s.add_runtime_dependency(%q<spox-plist>, [">= 0"])
      s.add_development_dependency(%q<rake>, [">= 0"])
    else
      s.add_dependency(%q<spox-textpow>, [">= 0"])
      s.add_dependency(%q<spox-plist>, [">= 0"])
      s.add_dependency(%q<rake>, [">= 0"])
    end
  else
    s.add_dependency(%q<spox-textpow>, [">= 0"])
    s.add_dependency(%q<spox-plist>, [">= 0"])
    s.add_dependency(%q<rake>, [">= 0"])
  end
end
