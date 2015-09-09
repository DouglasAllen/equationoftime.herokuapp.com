
require 'eot'
require 'bigdecimal'

class AnalemmaDataTable
  attr_accessor :year,
                :eot,
                :finish,
                :start,
                :span,
                :page,
                :table

  def initialize
    @year         = Time.now.utc.year
    @eot          = Eot.new
    @start        = Date.parse("#{@year}-1-1")
    @finish       = Date.parse("#{@year}-12-31")
    @span         = 0..(@finish - @start).to_i
    @page         = '<head>'
    @page         << '<link rel="stylesheet", type="text/css", href="/stylesheets/eot.css">'
    @page         << '</link></head><body>'
    build
  end

  def page_head
    @page << "<h2 align=center>Analemma Data for #{@year}</h2>"     
  end

  def table_head
    @page << '<div align="center">'
    @page << '<table>'
    @page << '<tbody>' 
    @page << '<tr><th></th><th></th>'
    @page << '<th> yday </th>'
    @page << '<th> date </th>'
    @page << '<th> Julian No. </th>'
    @page << '<th> Total  &Delta;T </th>'
    @page << '<th> Right Ascension </th>'
    @page << '<th> Oblique  &Delta;T </th>'
    @page << '<th> Declination </th>'
    @page << '<th> Orbital  &Delta;T </th>'
    @page << '<th></th><th></th></tr>' 
  end

  def table_body
      @span.each do |i|
        @eot.ajd  = (@start + i).jd
        @eot.ma_ta_set
        @page << '<tr><td><b><b/></td><td><b><b/></td>'
        @page << "<td><b>#{(@start + i).yday}<b/></td>"
        @page << "<td><b>#{(@start + i).month}/#{(@start + i).day}</b></td>"
        @page << "<td><b>#{(@start + i).jd}.0<b/></td>"
        @page << "<td><b>#{@eot.show_minutes(@eot.time_eot)}<b/></td>"
        @page << "<td><b>#{@eot.string_time((@eot.ra_sun * Eot::R2D) / 15.0)}<b/></td>"
        @page << "<td><b>#{@eot.show_minutes(@eot.time_delta_oblique)}<b/></td>"
        @page << "<td><b>#{@eot.string_dec_sun}<b/></td>"
        @page << "<td><b>#{@eot.show_minutes(@eot.time_delta_orbit)}<b/></td>"        
        @page << '<td><b><b/></td><td><b><b/></td></tr>'
    end
  end

  def table_foot
    @page << '</tbody></table></div>'
  end

  def build
    page_head
    table_head 
    table_body
    table_foot
    @page << '</body>'
   end
end

if __FILE__ == $PROGRAM_NAME
end
