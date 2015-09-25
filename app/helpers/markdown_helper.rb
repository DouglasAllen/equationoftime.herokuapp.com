
module MarkdownHelper
  
  if ENV.fetch("RACK_ENV") == "development"
    p "you're in #{__FILE__}"
  end

end

