# config.ru
#

require File.expand_path('../config/environment',  __FILE__)

app = Rack::Builder.new do
  #use Rack::Reloader
  #use Rack::CommonLogger
  use Rack::ShowExceptions
  
  map '/public' do  
    @root = File.expand_path(File.dirname(__FILE__) + "/public")
    run lambda {|env| Rack::Directory.new(@root).call(env)}
  end
  
  #:theme => "minimal_theme",
  #:lines => true,            
  
  # use Rack::Codehighlighter, :ultraviolet,
  #                           :markdown => true,                       
  #                           :element => 'pre>code', 
  #                           :pattern => /\A```(\w+)\s*(\n|&#x000A;)/i,
  #                           :themes => {'blackboard' => ['ruby'], 
  #                                       'zenburnesque' => ['c', 'sql'],
  #                                       'dawn' => ['html']},
  #                           :logging => false,
  #                           :lines => true  
                              
  #use Rack::Highlighter, :pygments
  #use Rack::Pygmentize
                             
  map '/' do  
    #run Sinatra::Application
    run EotSite
  end 
  
end.to_app

run app
