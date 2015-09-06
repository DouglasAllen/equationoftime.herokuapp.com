# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'celes/version'

Gem::Specification.new do |gem|
  gem.name          = "celes"
  gem.version       = Celes::VERSION
  gem.authors       = ["Naoki Arita"]
  gem.email         = ["ToNaokiArita@gmail.com"]
  gem.description   = %q{A library for astronomical computing.}
  gem.summary       = %q{A wrapper of the SOFA Library for Ruby.}
  gem.license       = "3-clause BSD"
  gem.homepage      = "https://github.com/tohka/celes"
  gem.extensions   << "ext/celes/extconf.rb"

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["ext", "lib"]
  gem.required_ruby_version = ">= 1.8.7"
end
