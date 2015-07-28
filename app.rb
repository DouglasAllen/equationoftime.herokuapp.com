# app.rb
#
#require 'dm-core'
#require 'dm-migrations'
require 'cgi'

require 'haml'
require 'sinatra'
#require 'jquery'
require 'find'
#require 'rdiscount'
#require 'liquid'
require 'sinatra/reloader' if development?
#require 'json/pure'

#DataMapper.setup(:default, 'sqlite3::memory:')
 
#class Message
#  include DataMapper::Resource
 
#  property :id, Serial
#  property :name, String
#  property :message, String
#end
 
#Message.auto_migrate!


#lib = File.expand_path('../lib', __FILE__)
#$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

def get_files(path)
  dir_list_array = Array.new
  Find.find(path) do |f|
    dir_list_array << File.basename(f, ".*") if !File.directory?(f) 
  end
  dir_list_array
end

helpers do
  def formatter(page)
    formatted = ""
    formatted = page.gsub(/[-]/, ' ').capitalize
    return formatted
  end
end  

require 'eot'
require_relative 'public/ad_table'

configure do
  Sinatra::Application.reset!
  use Rack::Reloader
end

before do
  @pi             = Math::PI
  
  @adt            = AnalemmaDataTable.new
  @r2d            = Eot::R2D
  @henge          = Eot.new
  
  @henge.latitude = 51.1789
  @henge.longitude= -1.8264
  @henge.ajd      = DateTime.now.to_time.utc.to_datetime.jd.to_f
  
  @gst            = Eot.new
  @gst.ajd        = DateTime.now.to_time.utc.to_datetime.ajd.to_f
  @gst.ma_ta_set  
  @gst.latitude   = 51.476853
  @gst.longitude  = -0.0005
  @gmst           = @gst.tl_aries / 15.0 * @r2d
  @st             = "The Greenwich Mean Sidereal Time is #{@gst.string_time(@gmst)[0..7]}"
  @eot            = "The Equation of Time is #{@gst.string_eot()}" 
  @utc            = "The time is #{Time.now.utc}"
  @msg            = "Today's sunrise and sunset at the Royal Observatory in Greenwich"
  @rise           = "#{(@henge.sunrise_dt()).to_time.utc}"
  @set            = "#{(@henge.sunset_dt()).to_time.utc}"
  @universal_time = DateTime.now.to_time.utc 
  @year           = @universal_time.year.to_s 
  @month          = @universal_time.month.to_s 
  @day            = @universal_time.day.to_s 
  @date_string    = @year << "-" << @month << "-" << @day
  @current        = @universal_time.to_datetime
  @day_fraction   = @current.day_fraction.to_f
  @solar          = Eot.new
  @solar.ajd      = @current.jd.to_f
  @solar.date     = DateTime.now.to_time.utc.to_date
  @solar.jd       = @solar.date.jd   
  @now            = @solar.t
  @ma             = @solar.ma_sun()   * @r2d  
  @eqc            = @solar.center()   * @r2d  
  @ta             = @solar.ta_sun()   * @r2d 
  @gml            = @solar.gml_sun()  * @r2d
  @tl             = @solar.tl_sun()   * @r2d  
  @mo             = @solar.mo_earth() * @r2d
  @to             = @solar.to_earth() * @r2d
  @al             = @solar.al_sun()   * @r2d
  @ra             = @solar.ra_sun()   * @r2d  
  @ma_string      = @solar.string_ma_sun()
  @eqc_string     = @solar.string_eqc()
  @tl_string      = @solar.string_tl_sun()
  @ra_string      = @solar.string_ra_sun()
  @et             = @solar.string_eot()
  @s_min          = 4.0 * 360 / 360.98564736629 # 3.989078265
  @e1             = (@ma - @ta) * @s_min
  @geo            = GeoLatLng.new
end

class HelpTime
  def page    
    :stonehenge
  end
  def get_time
    Time.now.utc
  end
end

get "/" do   
  haml :stonehenge, :layout => (request.xhr? ? false : :layout)
end

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
  haml :tut
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

