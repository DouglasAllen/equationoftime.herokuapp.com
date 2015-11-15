require File.expand_path('../boot', __FILE__)

    
class EotSite < Sinatra::Base

  if ENV.fetch("RACK_ENV") == "development"
    "you're in #{__FILE__}"
  end  

  APP_ROOT = Pathname.new(File.expand_path('../../', __FILE__))

  configure do 
    
    set :root, APP_ROOT.to_path

    Haml::Options.defaults[:format] = :xhtml

    Tilt.prefer Sinatra::Glorify::Template
    register Sinatra::Glorify 

    set :views,    lambda { File.join(APP_ROOT, 'app/views') }
    Dir[APP_ROOT.join('app', 'views', '*.rb')].each { |file| require file }

    require APP_ROOT.join('config', 'routes')

  end  
end