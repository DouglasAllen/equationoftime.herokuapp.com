######################
#  config/routes.rb  #
######################

class EotSite

  if ENV.fetch("RACK_ENV") == "development"
    p "you're in #{__FILE__}"
  end

  get "/", &HOME

  get "/tutorial", &TUTORIAL 

  get "/graph", &GRAPH

  get "/wikipedia", &WIKIPEDIA

  get "/analemma", &DATA

  get "/eot", &EOT

  get '/md', &MD

  get '/rdoc', &RDOC

  get "/gm", &GM

  get "/links", &LINKS

  get "/examples", &EXAMPLES

  get "/datetime", &DT
 
  get "/jcft", &JCFT

  get "/mean", &MEAN

  get "/eqc", &EQC

  get "/ecliplon", &ELN

  get "/rghtascn", &RA

  get "/final", &FIN

  get "/suntimes", &block = lambda { haml :suntimes }

  post "/suntimes", &block = lambda { haml :suntimes }

  get "/julian", &block = lambda { haml :julian }

  get "/solar", &block = lambda { haml :solar } 

  get "/factor", &block = lambda { haml :star_time } 

  get "/mysuntimes", &block = lambda { haml :mysuntimes } 

  get "/gist", &block = lambda { markdown :"gist", to_erb }

  get '/gist1', &block = lambda { haml :gist1 } 

  get '/sider', &block = lambda { haml :sider } 

  post "/sider2", &block = lambda { haml :stonehenge }

  get '/alex', &block = lambda { haml :alex } 

  get '/hello', &block = lambda { haml :hello }

  get "/home", &block = lambda { haml :index }

  get '/hellos' , &block = lambda { "Hello system!" }  

  get "/oopsa", &block = lambda { raise "oops" }

  get '/mdview/:link', &block = lambda { md_links }

  get '/rdview/:link', &block = lambda { rd_links }

  #get "/docs", &block = lambda {  }

  not_found do
    erb :not_found
  end

  get "/example" do
    erb :example_view
  end

end
   