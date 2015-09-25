require File.expand_path('../boot', __FILE__)
    
class EotSite < Sinatra::Base

  if ENV.fetch("RACK_ENV") == "development"
    p "you're in #{__FILE__}"
  end

  APP_ROOT = Pathname.new(File.expand_path('../../', __FILE__))
  
  configure do 
    
    set :root, APP_ROOT.to_path

    Tilt.prefer Sinatra::Glorify::Template
    register Sinatra::Glorify 

    set :views,    lambda { File.join(APP_ROOT, 'app/views') }
    Dir[APP_ROOT.join('app', 'views', '*.rb')].each { |file| require file }

    Dir[APP_ROOT.join('app', 'controllers', '*.rb')].each { |file| require file }
   
    Dir[APP_ROOT.join('app', 'helpers', '*.rb')].each { |file| require file }         

    #load_routes
    require APP_ROOT.join('config', 'routes')

  end
end
