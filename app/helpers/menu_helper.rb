
module MenuHelper

  if ENV.fetch("RACK_ENV") == "development"
    p "you're in #{__FILE__}"
  end

  @mc = MenuController.new

  HOME     = @mc.home
  TUTORIAL = @mc.tutorial
  GRAPH    = @mc.graph
  DATA     = @mc.data
  EOT      = @mc.eot
  MD       = @mc.md
  RDOC     = @mc.rdoc
  GM       = @mc.gm
  LINKS    = @mc.links
  EXAMPLES = @mc.examples
  
end