if ENV.fetch("RACK_ENV") == "development"
  p "you're in #{__FILE__}"
end

configure do   
  # Automatically load every file in APP_ROOT/app/models/*.rb, e.g.,
  #   autoload "Person", 'app/models/person.rb'
  #
  # We have to do this in case we have models that inherit from each other.
  # If model Student inherits from model Person and app/models/student.rb is
  # required first, it will throw an error saying "Person" is undefined.
  #
  # With this lazy-loading technique, Ruby will try to load app/models/person.rb
  # the first time it sees "Person" and will only throw an exception if
  # that file doesn't define the Person class.
  #
  # See http://www.rubyinside.com/ruby-techniques-revealed-autoload-1652.html
  # Load all models from app/models, using autoload instead of require
  # See http://www.rubyinside.com/ruby-techniques-revealed-autoload-1652.html

  APP_ROOT = Pathname.new(File.expand_path('../../', __FILE__))
  Dir[APP_ROOT.join('app', 'models', '*.rb')].each do |model_file|
    filename = File.basename(model_file).gsub('.rb', '')
    autoload ActiveSupport::Inflector.camelize(filename), model_file
  end
end

#include ActiveRecord
#include ActiveRecord::ConnectionAdapters

database_config = YAML.load_file(File.join( [APP_ROOT, 'config', 'database.yml'] ))
#spec = ConnectionSpecification::Resolver.new(database_config).spec(:development)

configure :production do

  ActiveRecord::Base.establish_connection(database_config.fetch('default'))
  # Heroku controls what database we connect to by setting the DATABASE_URL 
  # environment variable.
  # We need to respect that if we want our Sinatra apps to run on Heroku without modification
  #url = ENV['DATABASE_URL']
  #db  = URI.parse(url)
  # db = URI.parse(ENV['DATABASE_URL'] || "postgres://localhost/#{APP_NAME}_#{Sinatra::Application.environment}")

  #DB_NAME = db.path[1..-1]

  # Note:
  #   Sinatra::Application.environment is set to the value of ENV['RACK_ENV']
  #   if ENV['RACK_ENV'] is set.  If ENV['RACK_ENV'] is not set, it defaults
  #   to :development
  
  #ActiveRecord::Base.establish_connection(
  #  :adapter  => db.scheme == 'postgres' ? 'postgresql' : db.scheme,
  #  :host     => db.host,
  #  :port     => db.port,
  #  :username => db.user,
  #  :password => db.password,
  #  :database => DB_NAME,
  #  :encoding => 'utf8'
  #)  
end

configure :development do

  # Log queries to STDOUT in development
#  if Sinatra::Application.development?
#    DB_NAME = 'db/development.sqlite3',
#    ActiveRecord::Base.logger = Logger.new(STDOUT)    
#    ActiveRecord::Base.establish_connection(
#      adapter:  'sqlite3',
#      database: 'db/development.sqlite3',      
#      show_exceptions: true,
#      encoding: 'utf8'
#    )
#    ActiveRecord::Base.establish_connection(database_config.fetch('development'))
#  end
end
