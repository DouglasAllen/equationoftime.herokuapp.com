## eot-site-routes.rb

```ruby

  ######################################
  #                                    #
  #  app/contollers/menu_contoller.rb  #
  #                                    #
  ######################################

require 'sinatra/base'

class MenuController

  if ENV.fetch("RACK_ENV") == "development"
    p "you're in #{__FILE__}"
  end

  def home;lambda { haml :home };end

  def tutorial;lambda { haml :tutorial };end  

  def data;lambda {haml :analemma};end

  def eot;lambda {haml :eot};end

  def md;lambda {md_arr; erb :md};end

  def links;lambda { haml :links };end

  def examples;lambda { haml :examples };end

  def graph;lambda {haml :graph};end
  
  def rdoc;lambda {rd_arr ; erb :rdoc };end

  def gm;lambda { markdown :"gm", to_erb };end

end

  ################################
  #                              #
  #  app/helpers/menu_helper.rb  #
  #                              #
  ################################

require 'sinatra/base'

helpers do

  if ENV.fetch("RACK_ENV") == "development"
    p "you're in #{__FILE__}"
  end

  @mc = MenuController.new

    HOME     = @mc.home
    TUTORIAL = @mc.tutorial
    GRAPH    = @mc.graph
    DATA     = @mc.data
    EOT      = @mc.eot
    MD       = @mc.md
    RDOC     = @mc.rdoc
    GM       = @mc.gm
    LINKS    = @mc.links
    EXAMPLES = @mc.examples
 

end

  #######################################
  #                                     #
  #  app/helpers/application_helper.rb  #
  #                                     #
  #######################################

# application_helper.rb

module ApplicationHelper

  if ENV.fetch("RACK_ENV") == "development"
    p "you're in #{__FILE__}"
  end

  def title(value = nil)
    @title = value if value
    @title ? "#{@title}" : "equationoftime.herokuapp.com/example_view.erb"
  end  

  def get_files(path)
    dir_list_array = Array.new
    Find.find(path) do |f|
      dir_list_array << File.basename(f, ".*") if !File.directory?(f) 
    end
    dir_list_array
  end
  
  def formatter(page)
    formatted = ""
    formatted = page.gsub(/[-]/, ' ').capitalize
    return formatted
  end

  def to_erb
    ngn = {:layout_engine => :erb} 
  end

  def md_arr
    @md_arr = get_files('./app/views/md')
  end

  def md_links
    halt 404 unless File.exist?("app/views/md/#{params[:link]}.md")
    markdown :"md/#{params[:link]}", to_erb
  end

  def rd_arr
    @rd_arr = get_files('./app/views/rdoc')
  end 

  def rd_links
    halt 404 unless File.exist?("app/views/rdoc/#{params[:link]}.rdoc")
    rdoc :"rdoc/#{params[:link]}", to_erb
  end
  
end

  ######################
  #                    #
  #  config/routes.rb  #
  #                    #
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
```   