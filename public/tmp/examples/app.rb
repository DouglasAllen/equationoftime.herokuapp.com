require 'sinatra'

get '/' do
  #"Hello world" 
  erb :index
end

get '/contact.html' do
  #"Hello World"
  erb :contact
end

get '/index.html' do
  #"Hello World"
  erb :index
end

get '/meetings.html' do
  #"Hello World"
  erb :meetings
end

get '/Calcium.html' do
  #"Hello World"
  erb :Calcium
end

get '/Al-Anon.html' do
  #"Hello World"
  erb :Al_Anon
end

get '/ms.html' do
  #"Hello World"
  erb :ms
end