require 'dl'
require 'dl/import'
module LibSum
  extend DL::Importer
  dlload './libsum.so'
  extern 'double sum(double*, int)'
  extern 'double split(double)'
end
a = [2.0, 3.0, 4.0]
sum = LibSum.sum(a.pack("d*"), a.count)
p "The input values are in an array = #{a}"
p "The sum = #{sum}"
p "The split or divide by 2 = #{LibSum.split(sum)}"
