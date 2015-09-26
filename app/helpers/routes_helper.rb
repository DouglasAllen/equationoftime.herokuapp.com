module RoutesHelper

  if ENV.fetch("RACK_ENV") == "development"
    p "you're in #{__FILE__}"
  end

  def to_erb
    ngn = {:layout_engine => :erb} 
  end

  def md_arr
    @md_arr = get_files('./app/views/md')
  end

  def md_links
    halt 404 unless File.exist?("app/views/md/#{params[:link]}.md")
    markdown :"md/#{params[:link]}", to_erb
  end

  def rd_arr
    @rd_arr = get_files('./app/views/rdoc')
  end 

  def rd_links
    halt 404 unless File.exist?("app/views/rdoc/#{params[:link]}.rdoc")
    rdoc :"rdoc/#{params[:link]}", to_erb
  end

  # might need this sometime if using jquery
  # # :layout => (request.xhr? ? false : :layout)
  # http://www.sitepoint.com/sinatras-little-helpers/

end 