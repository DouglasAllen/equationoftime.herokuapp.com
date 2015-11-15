######################
#  config/routes.rb  #
######################

require File.expand_path('../../app/helpers/adt_helper', __FILE__)
class EotSite

  if ENV.fetch("RACK_ENV") == "development"
    "you're in #{__FILE__}"
  end

  get "/" do
    haml :home 
  end

  get "/examples" do
    haml :examples
  end

  get "/graph" do
    haml :graph
  end

  get "/tutorial" do
    haml :tutorial
  end

  get "/datetime" do
    haml :datetime
  end

  get "/jcft" do
    haml :jcft
  end

  get "/mean" do
    haml :mean
  end

  get "/eqc" do
    haml :eqc
  end

  get "/ecliplon" do
    haml :ecliplon
  end

  get "/rghtascn" do
    haml :rghtascn
  end

  get "/final" do
    haml :final
  end

  get "/eot" do
    haml :eot
  end

  get "/mysuntimes" do
    haml :mysuntimes
  end

  get "/links" do
    haml :links
  end

  get "/gm" do
    haml :gmm
  end

  get "/analemma" do
    @page = AnalemmaDataTable.new
    haml :analemma
  end

  get "/sider" do
    haml :sider
  end

  get "/today" do
    haml :today
  end

  get "/justin" do
    haml :justin
  end

  not_found do
    erb :not_found
  end

  get "/example" do
    erb :example_view
  end

  get '/throw/:type' do
    content_type :html
    @defeat = {rock: :scissors, paper: :rock, scissors: :paper}
    @throws = @defeat.keys
    # the params[] hash stores querystring and form data.
    player_throw = params[:type].to_sym
    # in the case of a player providing a throw that is not valid,
    # we halt with a status code of 403 (Forbidden) and let them
    # know they need to make a valid throw to play.
    if !@throws.include?(player_throw)
      halt 403, "<h1>You must throw one of the following: #{@throws}</h1>"
    end
  
    # now we can select a random throw for the computer
    computer_throw = @throws.sample
    # compare the player and computer throws to determine a winner
    if player_throw == computer_throw
      "<h1>You tied with the computer. Try again!</h1>"
    elsif computer_throw == @defeat[player_throw]
      "<h1>Nicely done; #{player_throw} beats #{computer_throw}!</h1>"
    else
      "<h1>Ouch; #{computer_throw} beats #{player_throw}. Better luck next time!</h1>"
    end
  end

end
   