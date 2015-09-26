# More info at https://github.com/guard/guard#readme

guard :minitest do
  # with Minitest::Unit
  watch('test/eot/*_test.rb')
  watch('lib/eot/*.rb') { |m| "test/#{m[1]}test_#{m[2]}.rb" }

  # with Minitest::Spec
  watch('test/eot/*_spec.rb')
  watch('lib/eot/*.rb') { |m| "test/#{m[1]}_spec.rb" }

end
