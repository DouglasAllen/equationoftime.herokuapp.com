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

get "/suntimes" do
  haml :suntimes
end

get "/julian" do
  haml :julian
end

get "/solar" do
  haml :solar
end

get "/factor" do
  haml :star_time
end

get '/hello' do
  haml :hello
end

get '/hellos' do
  "Hello Sinatra!"
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
 

get '/md' do
   @arr = get_files('./views/md')
   erb :md
end

get '/view/:link' do
   halt 404 unless File.exist?("views/md/#{params[:link]}.md")
   @time = Time.new
   markdown :"md/#{params[:link]}", :layout_engine => :erb
end

get '/sider2' do
  haml :stonehenge
end

post "/sider2" do
  haml :stonehenge
end

get '/alex' do
  haml :alex
end

