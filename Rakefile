# rake db:setup is executed when application is set up for the first time on
# Shelly.
# rake db:migrate is executed during each deployment.
# In a sinatra app you're free to leave them empty or fill them with code
# specific to your application.
namespace :db do
  task :migrate
  task :setup
end

# Code below is used for one-time setup on Shelly Cloud and can be removed
# afterwards.
# To deploy a new version of code you only need to git push to the Shelly
# Cloud remote.
desc "Setup this application on Shelly Cloud"
task :shellyit do
  code_name = get_code_name
  puts "Creating the application on Shelly..."
  sh "shelly add --databases= --size=small --default-organization --code-name=#{code_name}"
  sleep 5 # wait for the ssh keys to propagate to the git subsystem
  puts "Committing newly generated Cloudfile..."
  sh "git add Cloudfile"
  sh "git commit -m 'Added Cloudfile'"
  puts "Pushing the code to Shelly..."
  sh "git push shelly master"
  puts "Starting the cloud..."
  sh "shelly start"
end

def get_code_name(default="#{ENV['USER']}-jruby-starter")
  print "Choose a unique application code name[default=#{default}]: "
  code_name = $stdin.gets.strip
  code_name.empty? ? default : code_name
end
