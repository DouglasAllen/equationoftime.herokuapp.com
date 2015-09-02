require 'sinatra'

get '/' do
  require 'eot'
  eot = Eot.new()
  @start = "2012-1-1"
  @start_date = Date.parse(@start).jd
  @finish = "2012-12-31"
  @finish_date = Date.parse(@finish).jd
  data = []
  # use range
  # for jd in @start_date..@finish_date
  (@start_date..@finish_date).each do |jd|   
    date = Date.jd(jd).to_s
    eot.ajd = jd
    
    # timejc = eot.time_julian_centurey(jd)
    eot.ma_ta_set
    
    timejc = eot.ta
    # depricated    
    # equation_of_time = eot.equation_of_time(timejc)
    equation_of_time = eot.eot
    # depricated    
    # degrees_declination = eot.declination(timejc)
    degrees_declination = eot.declination
    # depricated
    # delta_t = eot.display_equation_of_time(equation_of_time)
    delta_t = eot.string_eot
    declination = eot.degrees_to_s(degrees_declination)
    # similar to
    # puts "#{date}\t  #{delta_t}\t  #{declination}"
    ds = (date + " " + delta_t + " " + declination).split
    data << "<p>" + ds.join(' / ') + "</p>"
  end
  ds = data.join()
     
     "<html>
       <body>
         <p><b>Analemma Data for</b></p>
         <p>Start date = #@start = #@start_date</p>
         <p>Finish date = #@finish = #@finish_date</p>
         <p>Date / Delta / Declination</p>
         #{ds}

       </body>
     </html>"       
     

end