
# require_relative 'lib/equation_of_time'
require 'safe_yaml'

class AnalemmaDataTable

  attr_accessor  :data_hash, :finish, :start, :table, :html

  def initialize      
     
    #~ @file_path    = File.expand_path( File.dirname( __FILE__ ) + "/public/analemma_data.yml" )
    #~ @data_hash    = YAML::load( File.open( @file_path, 'r'), :safe => true).freeze    
    @start        = Time.utc( 2014, "jan", 1, 12, 0, 0 ).to_s    
    @finish       = Time.utc( 2014, "dec", 31, 12, 0, 0 ).to_s    
    @span         = Date.parse( @finish ).jd - Date.parse( @start ).jd
    
    @table        = ""
    @html         = ""
    @start_jd     = Date.parse(@start).jd.to_s
    @finish_jd    = Date.parse(@finish).jd.to_s

    (0..@span).each do |i|      
      @date        = @data_hash[i].fetch(":date_str")
      @delta_t     = @data_hash[i].fetch(":delta_et")      
      @delta_1     = @data_hash[i].fetch(":delta_e1")
      @delta_2     = @data_hash[i].fetch(":delta_e2")            
      @transit     = @data_hash[i].fetch(":transit0")
      @declination = @data_hash[i].fetch(":declinat")
      @jd          = @data_hash[i].fetch(":juliandn")
    
@table << <<EOS
<tr>
<td><b>#@date</b></td>
<td><b>#@delta_t</b></td>
<td><b>#@delta_1</b></td>
<td><b>#@delta_2</b></td>
<td><b>#@transit</b></td>
<td><b>#@declination</b></td>
<td><b>#@jd </b></td>
</tr>
EOS
      
    end
  end
  def html
    @html = <<EOH 
<h2>Analemma Data for 2014</h2>	 
<h3>Start date = #@start = #@start_jd JDN</h3>
<h3>Finish date = #@finish = #@finish_jd JDN</h3>  
<div>
<table border=\"1\" cellpadding=\"10\">
<tbody align=\"center\";>
<tr>
<th>Date</th>
<th>True - Mean</th>
<th>Delta Orbit</th>
<th>Delta Oblique</th>
<th>Transit offset time UTC lng 0</th>
<th>Declination</th>
<th>JDN</th>
</tr>
#{@table}
</tbody>
</table>
</div>
EOH
  end
  
end

if __FILE__ == $PROGRAM_NAME
  adt = AnalemmaDataTable.new
  # puts adt.data_hash[0].fetch(":delta_t")
  # puts adt.date
  # puts adt.data[0]
  # puts adt.html
end