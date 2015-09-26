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
    helpers ApplicationHelper
    helpers RoutesHelper
    helpers AnalemmaDataTableHelper
    helpers EotHelper
    helpers LinksHelper
    helpers MenuHelper
    helpers TutorialHelper         

    #load_routes
    require APP_ROOT.join('config', 'routes')

  end
end
    
=begin 
    helpers do
      def assert(condition)
        fail "something is terribly broken" unless condition
      end
    end

    get '/' do
      assert env['PATH_INFO'] == request.path_info
      final_result = response.finish
      assert Array === final_result
      assert final_result.length == 3
      assert final_result.first == 200
      "everything is fine"
    end

    
    APP_NAME = APP_ROOT.basename.to_s

    # set :app_file, lambda { File.join(APP_ROOT, 'config/application') }
    # set :app_file, lambda { File.join(APP_ROOT, 'app') }
    # require settings.app_file   

    Dir[APP_ROOT.join('app', 'views', '*.rb')].each { |file| require file }   
    
    # Set up the database and models    
    require APP_ROOT.join('config', 'database')

    # Need to require controllers this way to enable inheritance
    # but we won't use it untill needed someday.
    def self.load_controllers 
      files = Dir[APP_ROOT.join('app', 'controllers', '*.rb')]
      files.each do |controller_file|
        controller_file
        filename = File.basename(controller_file).gsub('.rb', '')
        camelized = ActiveSupport::Inflector.camelize(filename)
        autoload camelized, controller_file
      end
    end 

    #load_controllers
    set :controllers, lambda { File.join(APP_ROOT, 'app/controllers') }
    Dir[APP_ROOT.join('app', 'controllers', '*.rb')].each { |file| require file }    
    Dir.glob('./{helpers,controllers}/*.rb').each { |file| require file }

    helpers ApplicationHelper 
    p settings.helpers  
    Dir[APP_ROOT.join('app', 'helpers', '*.rb')].each { |file| require file }

    # get helpers first because routes needs to use find files method    

    require APP_ROOT.join('config', 'routes')
    set :routes,   lambda { File.join(APP_ROOT, 'config/routes') }
    require settings.routes        

    Tilt.prefer Sinatra::Glorify::Template
    register Sinatra::Glorify    
=end


=begin
    # enable :static, :logging, :dump_errors
    # disable :sessions, :run
    # set :raise_errors, Proc.new { settings.environment == :development }
    # p settings.raise_errors
    # set :show_exceptions, Proc.new {settings.environment == :development }
    # p settings.show_exceptions
    
    # See: http://www.sinatrarb.com/faq.html#sessions
    # enable :sessions
    # set :session_secret, ENV['SESSION_SECRET'] || 'this is a secret shhhhh'
    # p settings.session_secret
if development?
  #Bundler.require(:development)
  #require "sinatra/reloader"
  # set :environment, ENV["RACK_ENV"].to_sym || :development
  #configure do
  #  use BetterErrors::Middleware    
  #  BetterErrors.application_root = __dir__
  #end
  #configure do
  #  Sinatra::Application.reset!
  #  use Rack::Reloader
  #end  
  #disable :run # uncomment to use irb see below.
end
=end