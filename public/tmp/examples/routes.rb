# routes.rb #
#############

=begin
# root page
get "/" do   
  haml :stonehenge, :layout => (request.xhr? ? false : :layout)
end

# all the menue links
get "/home" do  
  haml :index
end

post "/index" do
  # params[:address] 
  @geo.addr = params[:address].to_s 
  @geo.set_coordinates
  # params[:latitude2]
  @latitude2 = @geo.lat
  # params[:longitude2]
  @longitude2 = @geo.lng
  # params[:latitude]
  @latitude = params[:latitude].to_f
  # params[:longitude]
  @longitude = params[:longitude].to_f
  @solar.latitude = @latitude
  @solar.longitude = @longitude   		
  haml :index
end

require_relative 'ad_table'
get "/analemma" do    
  @html = @adt.page
  #@html = "<h2>The module AnalemmaDataTable has been diconnected until a new script is built.
  #</br>Thanks for checking us out.</h2>"
  haml :analemma
end

get "/tut" do
  haml :tut
end

get "/links" do	
  haml :links
end

get "/eot" do
  haml :eot, :layout => (request.xhr? ? false : :layout)
end

# tutorial pages
get "/date" do	
  haml :date
end

get "/time" do	
  haml :time
end

get "/mean" do	
  haml :mean
end

get "/eqc" do	
  haml :eqc
end

get "/ecliplong" do	
  haml :ecliplong
end

get "/rghtascn" do	
  haml :rghtascn
end

get "/final" do
  haml :final
end

get "/mysuntimes" do	
  haml :mysuntimes
end

post "/mysuntimes" do
  p params[:address] 
  @geo.addr = params[:address].to_s 
  @geo.set_coordinates
  @latitude = @geo.lat.to_f
  @longitude = @geo.lng.to_f
  @solar.latitude = @latitude
  @solar.longitude =  @longitude		
  haml :mysuntimes
end

=end
