# Celes

Celes is a wrapper of the SOFA Library for Ruby.

The SOFA Library has many functions for astronomical computing. The original library is available in Fortran 77 and ANSI C. Please see for more information about the SOFA Library: http://www.iausofa.org/.

Celes is a derived work of the SOFA Library and includes original files in accordance with [the SOFA Software License](http://www.iausofa.org/tandc.html).

## Dependencies

Ruby 1.8.7 or later

## Licenses

The 3-clause BSD License, the names of organizations of Article 3 have the IAU and the SOFA.

## Installation

### from RubyGems

```sh
$ sudo gem install celes
```

### from source

```sh
$ # download Celes
$ git clone https://github.com/tohka/celes.git
$ cd celes
$ 
$ # build gem
$ rake build
$ 
$ # install with built gem file
$ sudo gem install pkg/celes-0.0.1.gem
```

### from source without gem file

```sh
$ # download Celes
$ git clone https://github.com/tohka/celes.git
$ cd celes
$ 
$ cd ext/celes
$ 
$ # create Makefile and do make
$ ruby ./extconf.rb
$ make
$ 
$ ls *.so
celes_core.so
```

## Usage

```ruby
require 'celes'

# UTC to TAI
p Celes::utctai(2400000.5, 45678.9)
#=> [2400000.5, 45678.90025462963]
```

## Documentation

Celes's documentation is unprepared, but Celes is based on the original SOFA Library.

For example, to convert Gregorian Calendar date into Julian Date.

```c
// in C, using the SOFA Library
#include <stdio.h>
#include "sofa.h"
#include "sofam.h"

int status;
double djm0, djm;

status = iauCal2jd(2000, 12, 23, &djm0, &djm);

if(status){
  printf("error or warning\n");
} else{
  printf("Julian Day is %f\n", djm0 + djm);
}
//=> Julian Day is 2451901.5
```

```ruby
# in Ruby, using Celes
require 'celes'

begin
  djm0, djm = Celes::cal2jd(2000, 12, 23)
rescue
  puts "error"
else
  if Celes::status.nonzero?
    puts "warning"
  else
    puts "Julian Day is #{djm0 + djm}"
  end
end
#=> Julian Day is 2451901.5
```

### Rules

* basically, according to the original SOFA Library
* functions' name are lower-case
* a prefix <var>iau</var> or <var>iau_</var> is removed
* some functions are bang functions, their arguments value are replaced and name are with '!'
  * <var>zp!</var>, <var>zr!</var>, <var>ir!</var>, <var>zpv!</var>, <var>rx!</var>, <var>ry!</var> and <var>rz!</var>
  * Celes has also non-bang functions, <var>zp</var>, <var>zr</var>, ...
* arguments for output are removed
* when they have multi returned values, return as array object
* functions do not return status code
* <var>Celes::status</var> returns a last status code
* raise exception if status code implies error

### Bang and non-bang functions

Methods for clearing a vector or a matrix, <var>zp!</var>, <var>zr!</var>, <var>ir!</var> and <var>zpv!</var>.

```ruby
# in Ruby

# vector
p1 = [1.0, 2.0, 3.0]

Celes::zp!(p1)
p p1 #=> [0.0, 0.0, 0.0]

# non-bang version, has no arguments
p2 = Celes::zp
p p2 #=> [0.0, 0.0, 0.0]
```

----

Methods for rotating a matrix about an axis, <var>rx!</var>, <var>ry!</var> and <var>rz!</var>.

```ruby
# in Ruby
format = "[%9.6f, %9.6f, %9.6f]"

# matrix
r1 = Celes::ir
puts format % r1[0] #=> [ 1.000000,  0.000000,  0.000000]
puts format % r1[1] #=> [ 0.000000,  1.000000,  0.000000]
puts format % r1[2] #=> [ 0.000000,  0.000000,  1.000000]

# rotate about z-axis
Celes::rz!(Math::PI/3.0, r1)
puts format % r1[0] #=> [ 0.500000,  0.866025,  0.000000]
puts format % r1[1] #=> [-0.866025,  0.500000,  0.000000]
puts format % r1[2] #=> [ 0.000000,  0.000000,  1.000000]

# non-bang version
r2 = Celes::rz(Math::PI/3.0, r1)
puts format % r1[0] #=> [ 0.500000,  0.866025,  0.000000]
puts format % r1[1] #=> [-0.866025,  0.500000,  0.000000]
puts format % r1[2] #=> [ 0.000000,  0.000000,  1.000000]

puts format % r2[0] #=> [-0.500000,  0.866025,  0.000000]
puts format % r2[1] #=> [-0.866025, -0.500000,  0.000000]
puts format % r2[2] #=> [ 0.000000,  0.000000,  1.000000]
```

### Original documentation

A documentation about the SOFA Library.

* http://www.iausofa.org/current_F.html#Documents (Fortran 77)
* http://www.iausofa.org/current_C.html#Documents (ANSI C)


