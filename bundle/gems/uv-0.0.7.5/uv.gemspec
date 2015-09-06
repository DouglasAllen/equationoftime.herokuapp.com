# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "uv/version"

Gem::Specification.new do |s|
    s.name              = "uv"
    s.version           = Uv::VERSION
    s.authors           = ["spox","chaffeqa"]
    s.email             = ["spox@modspox.com","chaffeqa@gmail.com"]
    s.homepage          = "https://github.com/chaffeqa/uv"
    s.description       = "Ruby powered syntax highlighting.  Ruby 1.9 port of Ultraviolet"
    s.summary           = %q(ultraviolet in ruby 1.9+)

    s.rubyforge_project = "uv"

    s.required_ruby_version = '>= 1.9.0'
    s.add_dependency    'spox-textpow'
    s.add_dependency    'spox-plist'

    s.add_development_dependency    'rake'

    s.files         = `git ls-files`.split("\n").delete_if {|f| f =~ /^broken_syntax/}
    s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
    s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
    s.require_paths = ["lib"]
end
