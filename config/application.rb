configure do  
  
  # By default, Sinatra assumes that the root is the file that calls the configure block.
  # Since this is not the case for us, we set it manually.
  set :root, APP_ROOT.to_path
  set :public_folder, Proc.new { File.join(APP_ROOT, "public") }
  #p File.join(APP_ROOT, "public")
  
  # See: http://www.sinatrarb.com/faq.html#sessions
  enable :sessions
  set :session_secret, ENV['SESSION_SECRET'] || 'this is a secret shhhhh'
  
  # Set the views to
  set :views, File.join(Sinatra::Application.root, "app", "views")

  # Set up the controllers, views, and helpers
  Dir[APP_ROOT.join('app', 'controllers', '*.rb')].each { |file| require file }
  
  # Set up the helpers
  Dir[APP_ROOT.join('app', 'helpers', '*.rb')].each { |file| require file }
  
  # get helpers first because routes needs to use find files method
  require APP_ROOT.join('config', 'routes')
  
  # Set up the database and models
  # require APP_ROOT.join('config', 'database')  
  
  #register Config 
  #SafeYAML::OPTIONS[:safe]# option (to :safe or :unsafe).
  #config_file File.join( [APP_ROOT, 'config', 'config.yml'] ) 

  # register do
    # def auth(type)
      # condition do
        # unless send("current_#{type}")
          # redirect '/login'
          # add_error!("Not authorized, please login.")
        # end
      # end
    # end
  # end 

  # use OmniAuth::Builder do
  #   provider :github, ENV['GITHUB_KEY'], ENV['GITHUB_SECRET']
  # end

end