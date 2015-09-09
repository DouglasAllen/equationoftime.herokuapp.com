# config.ru
#

require File.expand_path('../config/environment',  __FILE__)

app = Rack::Builder.new do
  #use Rack::Reloader
  #use Rack::CommonLogger
  #use Rack::ShowExceptions
  use Rack::Codehighlighter, :ultraviolet,
                             :markdown => true,
                             #:theme => "minimal_theme",
                             #:lines => true,                      
                             :element => "pre>code", 
                             :pattern => /\A```(\w+)\s*(\n|&#x000A;)/i,
                             :themes => {"blackboard" => ["ruby"], 
                                         "zenburnesque" => ["c", "sql"],
                                         "dawn" => ["html"]},
                             :logging => false 
                             
  map '/' do  
    run Sinatra::Application
  end
  
  map '/docs' do  
    @root = File.expand_path(File.dirname(__FILE__) + "/public")
    run lambda {|env| Rack::Directory.new(@root).call(env)}
  end
  
end.to_app

run app

#run Sinatra::Application