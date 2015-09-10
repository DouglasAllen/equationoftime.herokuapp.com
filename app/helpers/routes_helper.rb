def to_erb
  ngn = {:layout_engine => :erb} 
end

def md_arr
  @md_arr = get_files('./app/views/md')
end

def rd_arr
  @rd_arr = get_files('./app/views/rdoc')
end 

# might need this sometime if using jquery
# # :layout => (request.xhr? ? false : :layout) 