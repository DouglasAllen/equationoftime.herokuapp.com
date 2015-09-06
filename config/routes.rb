# routes.rb
#

get "/" do
  markdown :"eot", :layout_engine => :erb  
end

get '/md' do
  @arr = get_files('./app/views/md')  
  erb :md
end

get '/rdoc' do
   @arr = get_files('./app/views/rdoc')
   erb :rdoc
end

get "/home" do
  "Hello World"  
  haml :index
end

get "/gm" do
  #haml :gm #, :layout => (request.xhr? ? false : :layout)
  markdown :"gm", :layout_engine => :erb
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

get '/gist1' do
  haml :gist1
end

get '/update' do
  @solar.ajd = DateTime.now.to_time.utc.to_datetime.ajd.to_f
  s, ihmsf = Celes.a2tf(3, @solar.tl_aries + -88.743 * Eot::D2R)  
  @lst = "#{s} #{ihmsf[0]}:#{ihmsf[1]}:#{ihmsf[2]}.#{ihmsf[3]}"
  @html = "<h1><b>My LST = #{@lst}</b></h1>"
  haml :update, :layout => (request.xhr? ? false : :layout)  
end

get '/sider' do
  haml :sider 
end

get '/lst' do
  @solar.ajd =  DateTime.now.to_time.utc.to_datetime.ajd.to_f  
  s, ihmsf = Celes.a2tf(3, @solar.tl_aries)
  gst = "#{s} #{ihmsf[0]}:#{ihmsf[1]}:#{ihmsf[2]}.#{ihmsf[3]}"
  s, ihmsf = Celes.a2tf(3, @solar.tl_aries + -88.743 * Eot::D2R)  
  lst = "#{s} #{ihmsf[0]}:#{ihmsf[1]}:#{ihmsf[2]}.#{ihmsf[3]}"
  @html = "<h1><b><pre>" +
  "GST: #{gst}</br>LST: #{lst}</pre></b></h1>"
  erb :lst, :layout => (request.xhr? ? false : :layout)
end

get "/tut" do
  markdown :"tut", :layout_engine => :erb 
end

get "/graph" do
  markdown :"graph", :layout_engine => :erb
end

get "/gist" do
  markdown :"gist"
end

get "/eot" do
  haml :eot, :layout => (request.xhr? ? false : :layout)
end

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

get "/links" do	
  haml :links
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

get "/suntimes" do
  haml :suntimes
end

get "/julian" do
  haml :julian
end

get "/solar" do
  haml :solar
end

get "/final" do
  haml :final
end

get "/factor" do
  haml :star_time
end

get "/analemma" do
    
  @html = @adt.page
  #@html = "<h2>The module AnalemmaDataTable has been diconnected until a new script is built.
  #</br>Thanks for checking us out.</h2>"

  haml :analemma
end

get '/hello' do
  haml :hello
end

get '/hellos' do
  
end

get '/frank' do
  name = "Frank"
  "Hello #{name}"
end

get '/app:name' do
  name = params[:name]
  "Hi there #{name}!"
end

get '/:one/:two/:three' do
  "first: #{params[:one]}, second: #{params[:two]}, third: #{params[:three]}"
end

get '/what/time/is/it/in/:number/hours' do
  number = params[:number].to_i
  time = Time.now + number * 3600
  "The time in #{number} hours will be #{time.strftime('%I:%M %p')}"
end

get '/gist1' do
  haml :gist1
end


post '/new' do
  @message = Message.new
  @message.message = "#{params[:will]} will #{params[:you]} you"
  @message.save
  
  @message.message
end 



get '/mdview/:link' do
   halt 404 unless File.exist?("app/views/md/#{params[:link]}.md")
   markdown :"md/#{params[:link]}", :layout_engine => :erb
end

get '/rdview/:link' do
  halt 404 unless File.exist?("app/views/rdoc/#{params[:link]}.rdoc")
  rdoc :"rdoc/#{params[:link]}", :layout_engine => :erb
end

require 'net/http'
require 'uri'
http = lambda do
  uri = URI('http://127.0.0.1:9393/rdoc')
  res = Net::HTTP.get_response(uri)
  "#{res}"
  #res.code
  #res.body if res.response_body_permitted?
  #request = Net::HTTP::Get.new uri
  "#{net.send_request('GET', '/index.haml')}"
  #response = net.request request # Net::HTTPResponse object
  #"#{uri}, #{net}, #{request}, #{response}"
end

get '/http', &http

post "/sider2" do
  haml :stonehenge
end

get '/alex' do
  haml :alex
end
