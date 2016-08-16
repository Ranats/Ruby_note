require 'sinatra'
#require 'sinatra/reloader'
require 'slim'
#require 'timers'
require 'sass'

get '/' do
  @title = '中間発表'
  slim :index
end

get '/setting' do
  slim :setting
end

post '/confirm' do
  p params[:title]
  @title = params[:title]
  @deadline = {Y:params[:year],M:params[:month],D:params[:day],h:params[:hour],m:params[:min],s:params[:sec]}
  slim :index
end


get '/style.css' do
  scss :style
end
