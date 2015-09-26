 http://ruby-doc.org/core-2.1.1/ENV.html

## Class ENV < Object

  ENV is a hash-like accessor for environment variables.
Public Class Methods

### ENV[name]

ENV[name] → value

  Retrieves the value for environment variable name as a String. Returns nil if the named
variable does not exist.

### ENV[name] =

ENV[name] = value

  Sets the environment variable name to value. If the value given is nil the environment
variable is deleted.

### assoc(name)

assoc(name) → Array or nil

  Returns an Array of the name and value of the environment variable with name or nil if the
name cannot be found.

### clear

clear

  Removes every environment variable.
  
### delete(name)

delete(name) → value
delete(name) { |name| } → value

  Deletes the environment variable with name and returns the value of the variable.
If a block is given it will be called when the named environment does not exist.

### delete_if

delete_if { |name, value| } → Hash
delete_if → Enumerator

  Deletes every environment variable for which the block evaluates to true.

  If no block is given an enumerator is returned instead.

### each

each { |name, value| } → Hash
each → Enumerator
each_pair { |name, value| } → Hash
each_pair → Enumerator

  Yields each environment variable name and value.

  If no block is given an Enumerator is returned.

### each_key

each_key { |name| } → Hash
each_key → Enumerator

  Yields each environment variable name.

  An Enumerator is returned if no block is given.

### each_pair

each_pair { |name, value| } → Hash
each_pair → Enumerator

  Yields each environment variable name and value.

  If no block is given an Enumerator is returned.

### each_value

each_value { |value| } → Hash
each_value → Enumerator

  Yields each environment variable value.

  An Enumerator is returned if no block was given.

empty? → true or false
Returns true when there are no environment variables

### fetch(name)

fetch(name) → value
fetch(name, default) → value
fetch(name) { |missing_name| ... } → value

  Retrieves the environment variable name.

  If the given name does not exist and neither default nor a block a provided an IndexError
is raised. If a block is given it is called with the missing name to provide a value.
If a default value is given it will be returned when no block is given.

### has_key?(name)

has_key?(name) → true or false

  Returns true if there is an environment variable with the given name.

### has_value?(value)

has_value?(value) → true or false

  Returns true if there is an environment variable with the given value.

### include?(name)

include?(name) → true or false

  Returns true if there is an environment variable with the given name.

### index(value)

index(value) → key

  Deprecated method that is equivalent to ::key

### inspect

inspect → string

  Returns the contents of the environment as a String.

### invert

invert → Hash

  Returns a new hash created by using environment variable names as values and values as names.

### keep_if

keep_if { |name, value| } → Hash
keep_if → Enumerator

  Deletes every environment variable where the block evaluates to false.

  Returns an enumerator if no block was given.

### key(value)

key(value) → name

  Returns the name of the environment variable with value. If the value is not found nil is
returned.

### key?(name)

key?(name) → true or false

  Returns true if there is an environment variable with the given name.

### keys

keys → Array

  Returns every environment variable name in an Array

### length

length

  Returns the number of environment variables.

### member?(name

member?(name) → true or false

  Returns true if there is an environment variable with the given name.

### rassoc(value)

rassoc(value)

  Returns an Array of the name and value of the environment variable with value or nil if the
value cannot be found.

### rehash

rehash

  Re-hashing the environment variables does nothing. It is provided for compatibility with
Hash.

### reject

reject { |name, value| } → Hash
reject → Enumerator

  Same as ENV#delete_if, but works on (and returns) a copy of the environment.

### reject!

reject! { |name, value| } → ENV or nil
reject! → Enumerator

  Equivalent to ENV#delete_if but returns nil if no changes were made.

  Returns an Enumerator if no block was given.

### replace(hash)

replace(hash) → env

  Replaces the contents of the environment variables with the contents of hash.

### select

select { |name, value| } → Hash
select → Enumerator

  Returns a copy of the environment for entries where the block returns true.

  Returns an Enumerator if no block was given.

### select!

select! { |name, value| } → ENV or nil
select! → Enumerator

  Equivalent to ENV#keep_if but returns nil if no changes were made.

### shift

shift → Array or nil

  Removes an environment variable name-value pair from ENV and returns it as an Array.
Returns nil if when the environment is empty.

### size

size

  Returns the number of environment variables.

### store(name, value)

store(name, value) → value

  Sets the environment variable name to value. If the value given is nil the environment
variable is deleted.

### to_a

to_a → Array

  Converts the environment variables into an array of names and value arrays.

ENV.to_a # => [["TERM", "xterm-color"], ["SHELL", "/bin/bash"], ...]

### to_h

to_h → hash

  Creates a hash with a copy of the environment variables.

### to_hash

to_hash → hash

  Creates a hash with a copy of the environment variables.

### to_s

to_s → "ENV"

  Returns “ENV”

### update(hash)

update(hash) → Hash
update(hash) { |name, old_value, new_value| } → Hash

  Adds the contents of hash to the environment variables. If no block is specified entries
with duplicate keys are overwritten, otherwise the value of each duplicate name is determined
by calling the block with the key, its value from the environment and its value from the hash.

### value?(value)

value?(value) → true or false

  Returns true if there is an environment variable with the given value.

### values

values → Array
 
  Returns every environment variable value as an Array

### values_at(name, ...)

values_at(name, ...) → Array

  Returns an array containing the environment variable values associated with the given names.
See also ::select.

