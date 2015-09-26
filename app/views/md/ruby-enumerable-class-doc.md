http://ruby-doc.org/core-2.2.3/Enumerable.html

## module Enumerable

The Enumerable mixin provides collection classes with several traversal and searching methods, 
and with the ability to sort. The class must provide a method each, which yields successive 
members of the collection. If Enumerable#max, #min, or #sort is used, the objects in the 
collection must also implement a meaningful <=> operator, as these methods rely on an ordering 
between members of the collection.

In Files

enum.c 

### Public Instance Methods

### all?

all? [{|obj| block } ] → true or false

Passes each element of the collection to the given block. The method returns true if the 
block never returns false or nil. If the block is not given, Ruby adds an implicit block of 
{|obj| obj} (that is all? will return true only if none of the collection members are false 
or nil.)

```ruby
%w{ant bear cat}.all? {|word| word.length >= 3}   #=> true
%w{ant bear cat}.all? {|word| word.length >= 4}   #=> false
[ nil, true, 99 ].all?                            #=> false
```


### any?

any? [{|obj| block } ] → true or false

Passes each element of the collection to the given block. The method returns true if the 
block ever returns a value other than false or nil. If the block is not given, Ruby adds an 
implicit block of {|obj| obj} (that is any? will return true if at least one of the collection 
members is not false or nil.

```ruby
%w{ant bear cat}.any? {|word| word.length >= 3}   #=> true
%w{ant bear cat}.any? {|word| word.length >= 4}   #=> true
[ nil, true, 99 ].any?                            #=> true
```

### chunk

chunk {|elt| ... } → an_enumerator

chunk(initial\_state) {|elt, state| ... } → an_enumerator 

Creates an enumerator for each chunked elements. The consecutive elements which have 
same block value are chunked.

The result enumerator yields the block value and an array of chunked elements. So “each” 
method can be called as follows.

enum.chunk {|elt| key }.each {|key, ary| ... }

enum.chunk(initial\_state) {|elt, state| key }.each {|key, ary| ... }

For example, consecutive even numbers and odd numbers can be splitted as follows.

```ruby
[3,1,4,1,5,9,2,6,5,3,5].chunk {|n|
                      n.even? }.each {|even, ary|
                        p [even, ary]}
# => [false, [3, 1]]
#    [true, [4]]
#    [false, [1, 5, 9]]
#    [true, [2, 6]]
#    [false, [5, 3, 5]]
```

This method is especially useful for sorted series of elements. The following example counts 
words for each initial letter.

```ruby
open("/usr/share/dict/words", "r:iso-8859-1") {|f|
  f.chunk {|line| line.ord }.each {|ch, lines| p [ch.chr, lines.length] }
}
    
# => ["\n", 1]
#    ["A", 1327]
#    ["B", 1372]
#    ["C", 1507]
#    ["D", 791]
#    ...
```

The following key values has special meaning:

  nil and :_separator specifies that the elements are dropped.

  :_alone specifies that the element should be chunked as a singleton.

Other symbols which begins an underscore are reserved.

nil and :_separator can be used to ignore some elements. For example, the sequence of 
hyphens in svn log can be eliminated as follows.

```ruby
sep = "-"*72 + "\n"
IO.popen("svn log README") {|f|
  f.chunk {|line|
    line != sep || nil
          }.each {|_, lines|
            pp lines
                 }
                           }

# => ["r20018 | knu | 2008-10-29 13:20:42 +0900 (Wed, 29 Oct 2008) | 2 lines\n", "\n",
#     "* README, README.ja: Update the portability section.\n", "\n"]
#    ["r16725 | knu | 2008-05-31 23:34:23 +0900 (Sat, 31 May 2008) | 2 lines\n", "\n",
#     "* README, README.ja: Add a note about default C flags.\n", "\n"]
#    ...
```

paragraphs separated by empty lines can be parsed as follows.
   
```ruby
File.foreach("README").chunk {|line|
  /\A\s*\z/ !~ line || nil
                             }.each {|_, lines|
                               pp lines
                                    }
```

:_alone can be used to pass through bunch of elements. For example, sort consecutive lines 
formed as Foo#bar and pass other lines, chunk can be used as follows.

```ruby
pat = /\A[A-Z][A-Za-z0-9_]+\#/
open(filename) {|f|
  f.chunk {|line| pat =~ line ? $& : :_alone }.each {|key, lines|
    if key != :_alone
      print lines.sort.join('')
    else
      print lines.join('')
    end
                                                    }
               }
```

If the block needs to maintain state over multiple elements, initial_state argument can be 
used. If non-nil value is given, it is duplicated for each “each” method invocation of the 
enumerator. The duplicated object is passed to 2nd argument of the block for “chunk” 
method.


### collect

collect {| obj | block } → array 

collect → an_enumerator 

Returns a new array with the results of running block once for every element in enum.

If no block is given, an enumerator is returned instead

```ruby
(1..4).collect {|i| i*i }   #=> [1, 4, 9, 16]
(1..4).collect { "cat"  }   #=> ["cat", "cat", "cat", "cat"]
```

### collect_concat

collect\_concat {| obj | block } → array 

collect\_concat → an_enumerator 

Returns a new array with the concatenated results of running block once for every element in 
enum.

If no block is given, an enumerator is returned instead.

```ruby
[[1,2],[3,4]].flat_map {|i| i }   #=> [1, 2, 3, 4]
```

### count

count → int count(item) → int 

count {| obj | block } → int 

Returns the number of items in enum, where size is called if it responds to it, otherwise the 
items are counted through enumeration. If an argument is given, counts the number of items 
in enum, for which equals to item. If a block is given, counts the number of elements yielding 
a true value.

```ruby
ary = [1, 2, 4, 2]
ary.count             #=> 4
ary.count(2)          #=> 2
ary.count{|x|x%2==0}  #=> 3
```

### cycle

cycle(n=nil) {|obj| block } → nil 

cycle(n=nil) → an_enumerator 

Calls block for each element of enum repeatedly n times or forever if none or nil is given. 
If a non-positive number is given or the collection is empty, does nothing. Returns nil if 
the loop has finished without getting interrupted.

Cycle saves elements in an internal array so changes to enum after the first pass have no 
effect.

If no block is given, an enumerator is returned instead.

```ruby
a = ["a", "b", "c"]
a.cycle {|x| puts x }  # print, a, b, c, a, b, c,.. forever.
a.cycle(2) {|x| puts x }  # print, a, b, c, a, b, c.
```

### detect

detect(ifnone = nil) {| obj | block } → obj or nil 

detect(ifnone = nil) → an_enumerator 

Passes each entry in enum to block. Returns the first for which block is not false. 
If no object matches, calls ifnone and returns its result when it is specified, 
or returns nil otherwise.

If no block is given, an enumerator is returned instead.

```ruby
(1..10).detect  {|i| i % 5 == 0 and i % 7 == 0 }   #=> nil
(1..100).detect {|i| i % 5 == 0 and i % 7 == 0 }   #=> 35
```

### drop

drop(n) → array 

Drops first n elements from enum, and returns rest elements in an array.

```ruby
a = [1, 2, 3, 4, 5, 0]
a.drop(3)             #=> [4, 5, 0]
```

### drop_while

drop\_while {|arr| block } → array 

drop\_while → an_enumerator 

Drops elements up to, but not including, the first element for which the block returns nil 
or false and returns an array containing the remaining elements.

If no block is given, an enumerator is returned instead.

```ruby
a = [1, 2, 3, 4, 5, 0]
a.drop_while {|i| i < 3 }   #=> [3, 4, 5, 0]
```

### each_cons

each\_cons(n) {...} → nil 

each\_cons(n) → an_enumerator 

Iterates the given block for each array of consecutive  elements. If no block is given, returns an enumerator.

e.g.:

```ruby
(1..10).each_cons(3) {|a| p a}
```

outputs below

```ruby
[1, 2, 3]
[2, 3, 4]
[3, 4, 5]
[4, 5, 6]
[5, 6, 7]
[6, 7, 8]
[7, 8, 9]
[8, 9, 10]
```

### each_entry

each\_entry {|obj| block} → enum 

each\_entry → an_enumerator 

Calls block once for each element in self, passing that element as a parameter, 
converting multiple values from yield to an array.

If no block is given, an enumerator is returned instead.

```ruby
class Foo
  include Enumerable
  def each
    yield 1
    yield 1,2
    yield
  end
end

Foo.new.each_entry{|o| p o }
```

produces:

```ruby
1
[1, 2]
nil
```

### each_slice

each\_slice(n) {...} → nil 

each\_slice(n) → an_enumerator 

Iterates the given block for each slice of  elements. If no block is given, returns an enumerator.

e.g.:

```ruby
(1..10).each_slice(3) {|a| p a}
```

outputs below

```ruby
[1, 2, 3]
[4, 5, 6]
[7, 8, 9]
[10]
```

### each\_with\_index

each\_with\_index(*args) {|obj, i| block } → enum 

each\_with\_index(*args) → an_enumerator 

Calls block with two arguments, the item and its index, for each item in enum. Given 
arguments are passed through to each().

If no block is given, an enumerator is returned instead.

```ruby
hash = Hash.new
%w(cat dog wombat).each_with_index {|item, index|
  hash[item] = index
                                   }

hash   #=> {"cat"=>0, "dog"=>1, "wombat"=>2}
```

### each\_with\_object

each\_with\_object(obj) {|(*args), memo_obj| ... } → obj 

each\_with\_object(obj) → an_enumerator 

Iterates the given block for each element with an arbitrary object given, and returns 
the initially given object.

If no block is given, returns an enumerator.

e.g.:

```ruby
evens = (1..10).each_with_object([]) {|i, a| a << i*2 }

#=> [2, 4, 6, 8, 10, 12, 14, 16, 18, 20]
```

### entries

entries → array 

Returns an array containing the items in enum.

```ruby
(1..7).entries                       #=> [1, 2, 3, 4, 5, 6, 7]
{ 'a'=>1, 'b'=>2, 'c'=>3 }.entries   #=> [["a", 1], ["b", 2], ["c", 3]]
```

### find

find(ifnone = nil) {| obj | block } → obj or nil 

find(ifnone = nil) → an_enumerator 

Passes each entry in enum to block. Returns the first for which block is not false. 
If no object matches, calls ifnone and returns its result when it is specified, or returns 
nil otherwise.

If no block is given, an enumerator is returned instead.

```ruby
(1..10).find  {|i| i % 5 == 0 and i % 7 == 0 }   #=> nil
(1..100).find {|i| i % 5 == 0 and i % 7 == 0 }   #=> 35
```

### find_all

find\_all {| obj | block } → array 

find\_all → an_enumerator 

Returns an array containing all elements of enum for which block is not false 
(see also Enumerable#reject).

If no block is given, an enumerator is returned instead.

```ruby
(1..10).find_all {|i|  i % 3 == 0 }   #=> [3, 6, 9]
```

### find_index

find\_index(value) → int or nil 

find\_index {| obj | block } → int or nil 

find\_index → an\_enumerator 

Compares each entry in enum with value or passes to block. Returns the index for the first 
for which the evaluated value is non-false. If no object matches, returns nil

If neither block nor argument is given, an enumerator is returned instead.

```ruby
(1..10).find_index  {|i| i % 5 == 0 and i % 7 == 0 }   #=> nil
(1..100).find_index {|i| i % 5 == 0 and i % 7 == 0 }   #=> 34
(1..100).find_index(50)                                #=> 49
```

### first

first → obj or nil 

first(n) → an\_array 

Returns the first element, or the first n elements, of the enumerable. If the enumerable is 
empty, the first form returns nil, and the second form returns an empty array.

```ruby
%w[foo bar baz].first     #=> "foo"
%w[foo bar baz].first(2)  #=> ["foo", "bar"]
%w[foo bar baz].first(10) #=> ["foo", "bar", "baz"]

[].first                  #=> nil
```

### flat_map

flat\_map {| obj | block } → array 

flat\_map → an\_enumerator 

Returns a new array with the concatenated results of running block once for every element in 
enum.

If no block is given, an enumerator is returned instead.

```ruby
[[1,2],[3,4]].flat_map {|i| i }   #=> [1, 2, 3, 4]
```

### grep

grep(pattern) → array 

grep(pattern) {| obj | block } → array 

Returns an array of every element in enum for which Pattern === element. If the optional 
block is supplied, each matching element is passed to it, and the block's result is stored 
in the output array.

```ruby
(1..100).grep 38..44   #=> [38, 39, 40, 41, 42, 43, 44]
c = IO.constants
c.grep(/SEEK/)         #=> [:SEEK_SET, :SEEK_CUR, :SEEK_END]
res = c.grep(/SEEK/) {|v| IO.const_get(v) }
res                    #=> [0, 1, 2]
```

### group_by

group\_by {| obj | block } → a_hash 

group\_by → an\_enumerator 

Returns a hash, which keys are evaluated result from the block, and values are arrays of 
elements in enum corresponding to the key.

If no block is given, an enumerator is returned instead.

```ruby
(1..6).group_by {|i| i%3}   #=> {0=>[3, 6], 1=>[1, 4], 2=>[2, 5]}
```

### include?

include?(obj) → true or false

Returns true if any member of enum equals obj. Equality is tested using ==.

```ruby
IO.constants.include? :SEEK_SET          #=> true
IO.constants.include? :SEEK_NO_FURTHER   #=> false
```

### inject
 
inject(initial, sym) → obj 

inject(sym) → obj 

inject(initial) {| memo, obj | block } → obj 

inject {| memo, obj | block } → obj 

Combines all elements of enum by applying a binary operation, specified by a block or a 
symbol that names a method or operator.

If you specify a block, then for each element in enum the block is passed an accumulator 
value (memo)and the element. If you specify a symbol instead, then each element in the 
collection will be passed to the named method of memo. In either case, the result becomes 
the new value for memo. At the end of the iteration, the final value of memo is the return 
value for the method.

If you do not explicitly specify an initial value for memo, then uses the first element of 
collection is used as the initial value of memo.

Examples:

Sum some numbers
    
```ruby
(5..10).reduce(:+)                            #=> 45
```

Same using a block and inject

```ruby
(5..10).inject {|sum, n| sum + n }            #=> 45
```

Multiply some numbers

```ruby
(5..10).reduce(1, :*)                         #=> 151200
```

Same using a block

```ruby
(5..10).inject(1) {|product, n| product * n } #=> 151200
```

find the longest word

```ruby
longest = %w{ cat sheep bear }.inject do |memo,word|
  memo.length > word.length ? memo : word
end

longest                                       #=> "sheep"
```

### map

map {| obj | block } → array 

map → an\_enumerator 

Returns a new array with the results of running block once for every element in enum.

If no block is given, an enumerator is returned instead.

```ruby
(1..4).collect {|i| i*i }   #=> [1, 4, 9, 16]
(1..4).collect { "cat"  }   #=> ["cat", "cat", "cat", "cat"]
```

### max

max → obj

max {|a,b| block } → obj 

Returns the object in enum with the maximum value. The first form assumes all objects 
implement Comparable; the second uses the block to return a <=> b.

```ruby
a = %w(albatross dog horse)
a.max                                  #=> "horse"
a.max {|a,b| a.length <=> b.length }   #=> "albatross"
```

### max_by

max\_by {|obj| block } → obj 

max\_by → an\_enumerator 

Returns the object in enum that gives the maximum value from the given block.

If no block is given, an enumerator is returned instead.

```ruby
a = %w(albatross dog horse)
a.max_by {|x| x.length }   #=> "albatross"
```

### member?

member?(obj) → true or false 

Returns true if any member of enum equals obj. Equality is tested using ==.

```ruby
IO.constants.member? :SEEK_SET          #=> true
IO.constants.member? :SEEK_NO_FURTHER   #=> false
```

### min

min → obj 

min {| a,b | block } → obj 

Returns the object in enum with the minimum value. The first form assumes all objects 
implement Comparable; the second uses the block to return a <=> b.

```ruby
a = %w(albatross dog horse)
a.min                                  #=> "albatross"
a.min {|a,b| a.length <=> b.length }   #=> "dog"
```

### min_by

min\_by {|obj| block } → obj 

min\_by → an\_enumerator 

Returns the object in enum that gives the minimum value from the given block.

If no block is given, an enumerator is returned instead.

```ruby
a = %w(albatross dog horse)
a.min_by {|x| x.length }   #=> "dog"
```

### minmax

minmax → [min,max]

minmax {|a,b| block } → [min,max] 

Returns two elements array which contains the minimum and the maximum value in the 
enumerable. The first form assumes all objects implement Comparable; the second uses the 
block to return a <=> b.

    
```ruby
a = %w(albatross dog horse)
a.minmax                                  #=> ["albatross", "horse"]
a.minmax {|a,b| a.length <=> b.length }   #=> ["dog", "albatross"]
```

### minmax_by

minmax\_by → an\_enumerator 

Returns two elements array array containing the objects in enum that gives the minimum and 
maximum values respectively from the given block.

If no block is given, an enumerator is returned instead.

```ruby
a = %w(albatross dog horse)
a.minmax_by {|x| x.length }   #=> ["dog", "albatross"]
```

### none?

none? [{|obj| block }] → true or false 

Passes each element of the collection to the given block. 
The method returns true if the block never returns true for all elements. 
If the block is not given, none? will return true only if none of the collection members is 
true.

```ruby
%w{ant bear cat}.none? {|word| word.length == 5}  #=> true
%w{ant bear cat}.none? {|word| word.length >= 4}  #=> false
[].none?                                          #=> true
[nil].none?                                       #=> true
[nil,false].none?                                 #=> true
```

### one?

one? [{|obj| block }] → true or false 

Passes each element of the collection to the given block. 
The method returns true if the block returns true exactly once. 
If the block is not given, one? will return true only if exactly one of the collection 
members is true.

```ruby
%w{ant bear cat}.one? {|word| word.length == 4}   #=> true
%w{ant bear cat}.one? {|word| word.length > 4}    #=> false
%w{ant bear cat}.one? {|word| word.length < 4}    #=> false
[ nil, true, 99 ].one?                            #=> false
[ nil, true, false ].one?                         #=> true
```

### partition

partition {| obj | block } → [ true\_array, false\_array ] 

partition → an\_enumerator 

Returns two arrays, the first containing the elements of enum for which the block evaluates 
to true, the second containing the rest.

If no block is given, an enumerator is returned instead.

```ruby
(1..6).partition {|v| v.even? }  #=> [[2, 4, 6], [1, 3, 5]]
```

### reduce

reduce(initial, sym) → obj 

reduce(sym) → obj 

reduce(initial) {| memo, obj | block } → obj 

reduce {| memo, obj | block } → obj 

Combines all elements of enum by applying a binary operation, specified by a block or a 
symbol that names a method or operator.

If you specify a block, then for each element in enum the block is passed an accumulator 
value (memo) and the element. If you specify a symbol instead, then each element in the 
collection will be passed to the named method of memo. In either case, the result becomes 
the new value for memo. At the end of the iteration, the final value of memo is the return 
value for the method.

If you do not explicitly specify an initial value for memo, then uses the first element of 
collection is used as the initial value of memo.

Examples:

Sum some numbers
    
```ruby
(5..10).reduce(:+)                            #=> 45
```

Same using a block and inject
    
```ruby
(5..10).inject {|sum, n| sum + n }            #=> 45
```

Multiply some numbers

```ruby
(5..10).reduce(1, :*)                         #=> 151200
```

Same using a block

```ruby
(5..10).inject(1) {|product, n| product * n } #=> 151200
```

find the longest word

```ruby
longest = %w{ cat sheep bear }.inject do |memo,word|
  memo.length > word.length ? memo : word
end
longest                                       #=> "sheep"
```

### reject

reject {| obj | block } → array 

reject → an\_enumerator 

Returns an array for all elements of enum for which block is false (see also Enumerable#find_all).

If no block is given, an enumerator is returned instead.

```ruby
(1..10).reject {|i|  i % 3 == 0 }   #=> [1, 2, 4, 5, 7, 8, 10]
```

### reverse_each

reverse\_each(*args) {|item| block } → enum  

reverse\_each(*args) → an\_enumerator 

Builds a temporary array and traverses that array in reverse order.

If no block is given, an enumerator is returned instead.

```ruby
(1..3).reverse_each {|v| p v }
```
produces:

```ruby
3
2
1
```

### select

select {| obj | block } → array

select → an\_enumerator

Returns an array containing all elements of enum for which block is not false 
(see also Enumerable#reject).

If no block is given, an enumerator is returned instead.

```ruby
(1..10).select {|i|  i % 3 == 0 }   #=> [3, 6, 9]
```

### slice_before

slice\_before(pattern) → an\_enumerator 

slice\_before {|elt| bool } → an\_enumerator 

slice\_before(initial\_state) {|elt, state| bool } → an\_enumerator 

Creates an enumerator for each chunked elements.
The beginnings of chunks are defined by _pattern_ and the block.
If \_pattern\_ === \_elt\_ returns true or
the block returns true for the element,
the element is beginning of a chunk.

The === and block is called from the first element to the last element
of \_enum\_.
The result for the first element is ignored.

The result enumerator yields the chunked elements as an array for **each**
method.
**each** method can be called as follows.

```ruby
enum.slice_before(pattern).each {|ary| ... }
enum.slice_before {|elt| bool }.each {|ary| ... }
enum.slice_before(initial_state) {|elt, state| bool }.each {|ary| ... }
```
Other methods of Enumerator class and Enumerable module,
such as map, etc., are also usable.

For example, iteration over ChangeLog entries can be implemented as
follows.

iterate over ChangeLog entries.

```ruby
open("ChangeLog") {|f|
  f.slice_before(/\A\S/).each {|e| pp e}
                  }
```

same as above.  block is used instead of pattern argument.
  
```ruby
open("ChangeLog") {|f|
  f.slice_before {|line| /\A\S/ === line }.each {|e| pp e}
                  }
```

“svn proplist -R” produces multiline output for each file. They can be chunked as follows:

```ruby
IO.popen([{"LC_ALL"=>"C"}, "svn", "proplist", "-R"]) {|f|
  f.lines.slice_before(/\AProp/).each {|lines| p lines }
                                                     }
  
# => ["Properties on '.':\n", "  svn:ignore\n", "  svk:merge\n"]
#    ["Properties on 'goruby.c':\n", "  svn:eol-style\n"]
#    ["Properties on 'complex.c':\n", "  svn:mime-type\n", "  svn:eol-style\n"]
#    ["Properties on 'regparse.c':\n", "  svn:eol-style\n"]
#    ...
```
If the block needs to maintain state over multiple elements,
local variables can be used.
For example, three or more consecutive increasing numbers can be squashed
as follows:

```ruby
a = [0,2,3,4,6,7,9]
prev = a[0]
p a.slice_before {|e|
  prev, prev2 = e, prev
  prev2 + 1 != e
                 }.map {|es|
    es.length <= 2 ? es.join(",") : "#{es.first}-#{es.last}"
                       }.join(",")
  
# => "0,2-4,6,7,9"
```
However local variables are not appropriate to maintain state
if the result enumerator is used twice or more.
In such case, the last state of the 1st **each** is used in 2nd **each**.
\_initial\_state\_ argument can be used to avoid this problem.
If non-nil value is given as \_initial\_state\_,
it is duplicated for each "each" method invocation of the enumerator.
The duplicated object is passed to 2nd argument of the block for
**slice\_before** method.

word wrapping.
this assumes all characters have same width.
  
```ruby
def wordwrap(words, maxwidth)
  # if cols is a local variable, 2nd "each" may start with non-zero cols.
  words.slice_before(cols: 0) {|w, h|
    h[:cols] += 1 if h[:cols] != 0
    h[:cols] += w.length
    if maxwidth < h[:cols]
      h[:cols] = w.length
      true
    else
      false
    end
                               }
end
  
text = (1..20).to_a.join(" ")
enum = wordwrap(text.split(/\s+/), 10)
puts "-"*10
enum.each {|ws| puts ws.join(" ") }
puts "-"*10
  
# => ----------
#    1 2 3 4 5
#    6 7 8 9 10
#    11 12 13
#    14 15 16
#    17 18 19
#    20
#    ----------
```

mbox contains series of mails which start with Unix From line. So each mail can be extracted 
by slice before Unix From line.

```ruby
# parse mbox
open("mbox") {|f|
  f.slice_before {|line|
    line.start_with? "From "
                 }.each {|mail|
                   unix_from = mail.shift
                   i = mail.index("\n")
                   header = mail[0...i]
                   body = mail[(i+1)..-1]
                   body.pop if body.last == "\n"
                   fields = header.slice_before {|line| !" \t".include?(line[0]) }.to_a
                   p unix_from
                   pp fields
                   pp body
                         }
             }
```

split mails in mbox (slice before Unix From line after an empty line)

```ruby
open("mbox") {|f|
  f.slice_before(emp: true) {|line,h
    prevemp = h[:emp]
    h[:emp] = line == "\n"
    prevemp && line.start_with?("From ")
                            }.each {|mail|
                              mail.pop if mail.last == "\n"
                              pp mail
                                   }
             }
```

### sort

sort → array 

sort {| a, b | block } → array 

Returns an array containing the items in enum sorted, either according to their own 
<=> method, or by using the results of the supplied block. 
The block should return -1, 0, or +1 depending on the comparison between a and b. 
As of Ruby 1.8, the method Enumerable#sort_by implements a built-in Schwartzian Transform, 
useful when key computation or comparison is expensive.

```ruby
%w(rhea kea flea).sort         #=> ["flea", "kea", "rhea"]
(1..10).sort {|a,b| b <=> a}   #=> [10, 9, 8, 7, 6, 5, 4, 3, 2, 1]
```

### sort_by

sort\_by {| obj | block } → array 

sort\_by → an\_enumerator 

Sorts enum using a set of keys generated by mapping the values in enum through the given 
block.

If no block is given, an enumerator is returned instead.

```ruby
%w{ apple pear fig }.sort_by {|word| word.length}
# => ["fig", "pear", "apple"]
```

The current implementation of sort\_by generates an array of tuples containing the original 
collection element and the mapped value. This makes sort\_by fairly expensive when the 
keysets are simple

```ruby
require 'benchmark'

a = (1..100000).map {rand(100000)}

Benchmark.bm(10) do |b|
  b.report("Sort")    { a.sort }
  b.report("Sort by") { a.sort_by {|a| a} }
end
```

produces:

```ruby
user     system      total        real
Sort        0.180000   0.000000   0.180000 (  0.175469)
Sort by     1.980000   0.040000   2.020000 (  2.013586)
```
    
However, consider the case where comparing the keys is a non-trivial operation. 
The following code sorts some files on modification time using the basic sort method.

```ruby
files = Dir["*"]
sorted = files.sort {|a,b| File.new(a).mtime <=> File.new(b).mtime}
sorted   #=> ["mon", "tues", "wed", "thurs"]
```

This sort is inefficient: it generates two new File objects during every comparison. 

A slightly better technique is to use the Kernel#test method to generate the modification 
times directly.

```ruby
files = Dir["*"]
sorted = files.sort { |a,b|
  test(M, a) <=> test(M, b)
                    }
sorted   #=> ["mon", "tues", "wed", "thurs"]
```

This still generates many unnecessary Time objects. A more efficient technique is to cache 
the sort keys (modification times in this case) before the sort. Perl users often call this 
approach a Schwartzian Transform, after Randal Schwartz. We construct a temporary array, 
where each element is an array containing our sort key along with the filename. We sort this
array, and then extract the filename from the result.

```ruby
sorted = Dir["*"].collect { |f|
  [test(M, f), f]
                          }.sort.collect { |f| f[1] }

sorted   #=> ["mon", "tues", "wed", "thurs"]
```

This is exactly what sort_by does internally.

```ruby
sorted = Dir["*"].sort_by {|f| test(M, f)}
sorted   #=> ["mon", "tues", "wed", "thurs"]
```

### take

take(n) → array  

Returns first n elements from enum.

```ruby
a = [1, 2, 3, 4, 5, 0]
a.take(3)             #=> [1, 2, 3]
```

### take_while

take\_while {|arr| block } → array 

take\_while → an\_enumerator 

Passes elements to the block until the block returns nil or false, then stops iterating 
and returns an array of all prior elements.

If no block is given, an enumerator is returned instead.

```ruby
a = [1, 2, 3, 4, 5, 0]
a.take_while {|i| i < 3 }   #=> [1, 2]
```

### to_a

to\_a → array  

entries → array 

Returns an array containing the items in enum.

```ruby
(1..7).to_a                       #=> [1, 2, 3, 4, 5, 6, 7]
{ 'a'=>1, 'b'=>2, 'c'=>3 }.to_a   #=> [["a", 1], ["b", 2], ["c", 3]]
```

### zip

zip(arg, ...) → an\_array\_of\_array  

zip(arg, ...) {|arr| block } → nil 

Takes one element from enum and merges corresponding elements from each args. 
This generates a sequence of n-element arrays, where n is one more than the count of arguments. 
The length of the resulting sequence will be enum#size. If the size of any argument is less 
than enum#size, nil values are supplied. If a block is given, it is invoked for each output 
array, otherwise an array of arrays is returned.

```ruby
a = [ 4, 5, 6 ]
b = [ 7, 8, 9 ]

[1,2,3].zip(a, b)      #=> [[1, 4, 7], [2, 5, 8], [3, 6, 9]]
[1,2].zip(a,b)         #=> [[1, 4, 7], [2, 5, 8]]
a.zip([1,2],[8])       #=> [[4, 1, 8], [5, 2, nil], [6, nil, nil]]
```
