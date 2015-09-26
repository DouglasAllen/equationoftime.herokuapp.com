
# require "rubygems"
require 'bundler/gem_tasks'
# require "bundler/install_tasks"
require 'hoe'

require 'rake/extensiontask'
require 'rake/testtask'
# require "rake/win32"
require 'rdoc/task'
require 'rspec/core/rake_task'
require 'yard'
# begin
#   require 'rubygems/gempackagetask'
# rescue LoadError
# end
# require 'rake/clean'
# require 'rbconfig'
# include RbConfig

# Hoe.plugins.delete :newb
# Hoe.plugins.delete :test
Hoe.plugins.delete :signing
Hoe.plugins.delete :publish
# Hoe.plugins.delete  :clean
# Hoe.plugins.delete :package
Hoe.plugins.delete :compiler
Hoe.plugins.delete :debug
Hoe.plugins.delete :rcov
Hoe.plugins.delete :gemcutter
Hoe.plugins.delete :racc
# Hoe.plugins.delete :inline
Hoe.plugins.delete :gem_prelude_sucks
Hoe.plugins.delete :flog
Hoe.plugins.delete :flay
# Hoe.plugins.delete :deps
# Hoe.plugins.delete :minitest
Hoe.plugins.delete :rdoc
# Hoe.plugins.delete :travis

# Hoe.plugin :newb
# Hoe.plugin :test
# Hoe.plugin :signing
# Hoe.plugin :publish
# Hoe.plugin :clean
# Hoe.plugin :package
# Hoe.plugin :compiler
# Hoe.plugin :debug
# Hoe.plugin :rcov
# Hoe.plugin :gemcutter
# Hoe.plugin :racc
# Hoe.plugin :inline
# Hoe.plugin :gem_prelude_sucks
# Hoe.plugin :flog
# Hoe.plugin :flay
# Hoe.plugin :deps
Hoe.plugin :minitest
# Hoe.plugin :rdoc
Hoe.plugin :travis

Hoe.spec 'equationoftime' do
  developer('Douglas Allen', 'kb9agt@gmail.com')
  license('MIT')
  
  #self.readme_file   = 'README.rdoc'
  #self.history_file  = 'CHANGELOG.rdoc'
  #self.extra_rdoc_files  = FileList[]
  extra_dev_deps << ['rake-compiler', '~> 0.9', '>= 0.9.3']
  #self.spec_extras = { extensions: ['ext/helio/extconf.rb'] }

  Rake::ExtensionTask.new('helio', spec) do |ext|
    ext.lib_dir = File.join('lib', 'eot')
  end
end

Rake::Task[:test].prerequisites << :compile

task default: [:test]

Rake::TestTask.new(:test) do |t|
  t.libs << 'test'
  t.test_files = FileList['test/eot/*_spec.rb']
  t.verbose = true
  t.options
end

# RSpec::Core::RakeTask.new(:spec) do | t |
#   t.pattern = './test/eot/*_spec.rb'
#   t.rspec_opts = []
# end

YARD::Rake::YardocTask.new(:yardoc) do |t|
  t.files = ['lib/eot/*.rb']
  #  puts t.methods
end

desc 'generate API documentation to rdocs/index.html'
Rake::RDocTask.new(:docs) do |rd|

  rd.rdoc_dir = 'rdocs'

  rd.rdoc_files.include 'lib/eot/*.rb', 'README.rdoc', 'wiki.md'

  rd.options << '--line-numbers'

end

# require 'rake/extensiontask'
# spec = Gem::Specification.load('equationoftime.gemspec')
# Rake::ExtensionTask.new('ceot', spec)
# Rake::ExtensionTask.new "ceot" do |ext|
# ext.lib_dir = "lib"
# end

# Rake::TestTask.new(:mine) do |t|

# Rake::Win32.rake_system("echo rspec ./tests/spec/aliased_angles_spec.rb")
# Rake::Win32.rake_system("rspec ./tests/spec/aliased_angles_spec.rb")

# Rake::Win32.rake_system("echo rspec ./tests/spec/aliased_displays_spec.rb")
# Rake::Win32.rake_system("rspec ./tests/spec/aliased_displays_spec.rb")

# Rake::Win32.rake_system("echo rspec ./tests/spec/aliased_utilities_spec.rb")
# Rake::Win32.rake_system("rspec ./tests/spec/aliased_utilities_spec.rb")

# Rake::Win32.rake_system("echo rspec ./tests/spec/angles_spec.rb")
# Rake::Win32.rake_system("rspec ./tests/spec/angles_spec.rb")

# Rake::Win32.rake_system("echo rspec ./tests/spec/constants_spec.rb")
# Rake::Win32.rake_system("rspec ./tests/spec/constants_spec.rb")

# Rake::Win32.rake_system("echo rspec ./tests/spec/displays_spec.rb")
# Rake::Win32.rake_system("rspec ./tests/spec/displays_spec.rb")

# Rake::Win32.rake_system("echo rspec ./tests/spec/init_spec.rb")
# Rake::Win32.rake_system("rspec ./tests/spec/init_spec.rb")

# Rake::Win32.rake_system("echo rspec ./tests/spec/nutation_spec.rb")
# Rake::Win32.rake_system("rspec ./tests/spec/nutation_spec.rb")

# Rake::Win32.rake_system("echo rspec ./tests/spec/times_spec.rb")
# Rake::Win32.rake_system("rspec ./tests/spec/times_spec.rb")

# Rake::Win32.rake_system("echo rspec ./tests/spec/utilities_spec.rb")
# Rake::Win32.rake_system("rspec ./tests/spec/utilities_spec.rb")

# Rake::Win32.rake_system("echo rspec ./tests/spec/vars_spec.rb")
# Rake::Win32.rake_system("rspec ./tests/spec/vars_spec.rb")

# end
