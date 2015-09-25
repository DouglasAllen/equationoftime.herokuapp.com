helpers do

  if ENV.fetch("RACK_ENV") == "development"
    p "you're in #{__FILE__}"
  end

  @lc = LinksController.new
  WIKIPEDIA = @lc.wikipedia

end
