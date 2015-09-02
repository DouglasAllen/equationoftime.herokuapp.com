# config.ru
#
require 'bundler'
Bundler.setup
require "./app.rb"

app = Rack::Builder.new do
  use Rack::Reloader
  use Rack::CommonLogger
  use Rack::ShowExceptions
  map '/' do  
    run Sinatra::Application
  end
  map '/docs' do  
    @root = File.expand_path(File.dirname(__FILE__) + "/public/htdocs/")
    run lambda {|env| Rack::Directory.new(@root).call(env)}
  end
end.to_app

run app

