class EotSite
if ENV.fetch("RACK_ENV") == "development"
  p "you're in #{__FILE__}"
end

get '/' do
  # This renders starter kit instructions. Replace it with your code once
  # you've completed them.
  if settings.views?
    if settings.production?
      haml :production
    else
      "#{settings.views}"
      haml :local
    end
  end
end
end