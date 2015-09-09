
require 'eot'
require 'bigdecimal'

class AnalemmaDataTable
  attr_accessor :eot,
                :finish,
                :start,
                :span,
                :page,
                :table

  def initialize
    @eot          = Eot.new
    @start        = Date.parse('2015-1-1')
    @finish       = Date.parse('2015-12-31')
    @span         = 0..(@finish - @start).to_i
    @page         = ''
    @table        = ''
    build
  end

  def page_head
    '<h2>Analemma Data for 2015</h2>' \
    "<h3>Start date = #{@start} = #{@start.jd} JDN</h3>" \
    "<h3>Finish date = #{@finish} = #{@finish.jd} JDN</h3>"     
  end

  def table_head
    '<table border="1" cellpadding="10">' \
    '<tbody align="center";>' \
    '<tr><th></th><th></th>' \
    '<th>2014 Date</th>' \
    '<th>JDN</th>' \
    '<th>Angle Delta Orbit</th>' \
    '<th>Angle Delta Oblique</th>' \
    '<th>Sum Delta Orbit and Delta Oblique</th>' \
    '<th></th><th></th></tr>' 
  end

  def table_body
      @span.each do |i|
        @eot.ajd  = (@start + i).jd
        @eot.ma_ta_set
        @table << '<tr><td><b><b/></td><td><b><b/></td>'
        @table << "<td><b>#{(@start + i).month}/#{(@start + i).day}</b></td>"
        @table << "<td><b>#{(@start + i).jd}<b/></td>"
        @table << "<td><b>#{(@eot.delta_orbit * Eot::R2D)}<b/></td>"
        @table << "<td><b>#{(@eot.delta_oblique * Eot::R2D)}<b/></td>"
        @table << "<td><b>#{(@eot.eot * Eot::R2D)}<b/></td>"
        @table << '<td><b><b/></td><td><b><b/></td></tr>'
    end
  end

  def table_foot
    '</tbody></table>'
  end

  def build
    @page << page_head
    @page << table_head 
    table_body
    @page << @table
    @page << table_foot
   end
end

# if __FILE__ == $PROGRAM_NAME
#   adt = AnalemmaDataTable.new
  
# end
