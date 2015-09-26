# The Ruby Programming Language

## CHAPTER 10

### The Ruby Environment

#### 10.1 Invoking the Ruby Interpreter

```ruby
ruby [<replaceable>options</replaceable>] [--] <replaceable>program</replaceable> [<replaceable>arguments</replaceable>]
```

#### 10.1.1 Common Options

```rdoc
require '<replaceable>library</replaceable>'
```

#### 10.1.4 Text Processing Options

```ruby
while gets             # Read a line of input into $_
  $F = split if $-a    # Split $_ into fields if -a was specified
  chop! if $-l         # Chop line ending off $_ if -l was specified
  # Program text here
end
###########################
while gets             # Read a line of input into $_
  $F = split if $-a    # Split $_ into fields if -a was specified
  chop! if $-l         # Chop line ending off $_ if -l was specified
  # Program text here
  print                # Output $_ (adding $/ if -l was specified)
end
```

#### 10.2.1 Predefined Modules and Classes

```ruby
Comparable      FileTest        Marshal         Precision
Enumerable      GC              Math            Process
Errno           Kernel          ObjectSpace     Signal
###########################
Array           File            Method          String
Bignum          Fixnum          Module          Struct
Binding         Float           NilClass        Symbol
Class           Hash            Numeric         Thread
Continuation    IO              Object          ThreadGroup
Data            Integer         Proc            Time
Dir             MatchData       Range           TrueClass
FalseClass      MatchingData    Regexp          UnboundMethod
###########################
ArgumentError           NameError               SignalException
EOFError                NoMemoryError           StandardError
Exception               NoMethodError           SyntaxError
FloatDomainError        NotImplementedError     SystemCallError
IOError                 RangeError              SystemExit
IndexError              RegexpError             SystemStackError
Interrupt               RuntimeError            ThreadError
LoadError               ScriptError             TypeError
LocalJumpError          SecurityError           ZeroDivisionError
###########################
BasicObject     FiberError      Mutex           VM
Fiber           KeyError        StopIteration
###########################
# Print all modules (excluding classes)
puts Module.constants.sort.select {|x| eval(x.to_s).instance_of? Module}

# Print all classes (excluding exceptions)
puts Module.constants.sort.select {|x|
  c = eval(x.to_s)
  c.is_a? Class and not c.ancestors.include? Exception
}

# Print all exceptions
puts Module.constants.sort.select {|x|
  c = eval(x.to_s)
  c.instance_of? Class and c.ancestors.include? Exception
}
```

#### 10.2.2 Top-Level Constants

```rdoc
ruby -e 'puts Module.constants.sort.reject{|x| eval(x.to_s).is_a? Module}'
```

#### 10.2.3 Global Variables

```rdoc
ruby -e 'puts global_variables.sort'
###########################
ruby -rEnglish -e 'puts global_variables.sort'
```

#### 10.2.4.1 Keyword functions

```ruby
block_given?    iterator?       loop            require
callcc          lambda          proc            throw
catch           load            raise
```

#### 10.2.4.2 Text input, output, and manipulation functions

```ruby
format          print           puts            sprintf
gets            printf          readline
p               putc            readlines
###########################
chomp   chop    gsub    scan    sub
chomp!  chop!   gsub!   split   sub!
```

#### 10.2.4.3 OS methods

```ruby
# `       fork    select  system  trap
# exec    open    syscall test
```

#### 10.2.4.4 Warnings, failures, and exiting

```ruby
abort   at_exit exit    exit!   fail    warn
```

#### 10.2.4.5 Reflection functions

```ruby
binding                         set_trace_func
caller                          singleton_method_added
eval                            singleton_method_removed
global_variables                singleton_method_undefined
local_variables                 trace_var
method_missing                  untrace_var
remove_instance_variable
```

#### 10.2.4.6 Conversion functions

```ruby
Array   Float   Integer String
```

#### 10.2.4.7 Miscellaneous Kernel functions

```ruby
autoload                rand                    srand
autoload?               sleep
```

#### 10.3.4 One-Line Script Shortcuts

```rdoc
ruby -n -e 'print if /^A/' datafile
###########################
print if $_ =~ /^A/
```

#### 10.4.1 Invoking OS Commands

```ruby
os = `uname`             # String literal and method invocation in one
os = %x{uname}           # Another quoting syntax
os = Kernel.`("uname")   #` Invoke the method explicitly
###########################
files = `` ` ``echo *.xml`` ` ``
###########################
pipe = open("|echo *.xml")
files = pipe.readline
pipe.close
```

#### 10.4.2 Forking and Processes

```ruby
fork {
  puts "Hello from the child process: #$$"
}
puts "Hello from the parent process: #$$"
###########################
pid = fork
if (pid)
  puts "Hello from parent process: #$$"
  puts "Created child process #{pid}"   
else
  puts Hello from child process: #$$"
end
###########################
open("|-", "r+") do |child|
  if child
    # This is the parent process
    child.puts("Hello child")       # Send to child
    response = child.gets           # Read from child
    puts "Child said: #{response}"
  else
    # This is the child process
    from_parent = gets              # Read from parent
    STDERR.puts "Parent said: #{from_parent}"
    puts("Hi Mom!")                 # Send to parent
  end
end
###########################
open("|-", "r") do |child|
  if child
    # This is the parent process
    files = child.readlines   # Read the output of our child
    child.close
  else
    # This is the child process
    exec("/bin/ls", "-l")     # Run another executable
  end
end
```

#### 10.4.3 Trapping Signals

```ruby
trap "SIGINT" {
  puts "Ignoring SIGINT"
}
```

#### 10.4.4 Terminating Programs

```ruby
fail "Unknown option #{switch}"
```

#### 10.5.2 Restricted Execution and Safe Levels

```ruby
$SAFE=1                # upgrade the safe level
$SAFE=4                # upgrade the safe level even higher
$SAFE=0                # SecurityError!  you can't do it
###########################
Thread.start {     # Create a "sandbox" thread
  $SAFE = 4        # Restrict execution in this thread only
  ...              # Untrusted code can be run here
}
```

#### 10.5.2.3 Safe level 2

```ruby
Dir.chdir               File.truncate           Process.egid=
Dir.chroot              File.umask              Process.fork
Dir.mkdir               IO.fctrl                Process.kill
Dir.rmdir               IO.ioctl                Process.setpgid
File.chmod              Kernel.exit!            Process.setpriority
File.chown              Kernel.fork             Process.setsid
File.flock              Kernel.syscall
File.lstat              Kernel.trap
###########################
def safe_eval(str)
  Thread.start {            # Start sandbox thread
    $SAFE = 4               # Upgrade safe level
    eval(str)               # Eval in the sandbox
  }.value                   # Retrieve result
end
```
