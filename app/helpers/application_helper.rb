# application_helper.rb

  module ApplicationHelper

    if ENV.fetch("RACK_ENV") == "development"
      p "you're in #{__FILE__}"
    end

    def title(value = nil)
      @title = value if value
      @title ? "#{@title}" : "equationoftime.herokuapp.com/example_view.erb"
    end  

    def get_files(path)
      dir_list_array = Array.new
      Find.find(path) do |f|
        dir_list_array << File.basename(f, ".*") if !File.directory?(f) 
      end
      dir_list_array
    end
  
    def formatter(page)
      formatted = ""
      formatted = page.gsub(/[-]/, ' ').capitalize
      return formatted
    end
  
end
