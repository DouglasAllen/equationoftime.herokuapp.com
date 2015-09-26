# eot_methods_list.rb

require 'eot'
eot = Eot.new
list = eot.public_methods(false).sort
list.each { |i| puts i.to_sym }
puts Time.now
