# DidacticClock

TODO: Write a gem description

## Installation

Add this line to your application's Gemfile:

    gem 'didactic_clock'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install didactic_clock

## Usage
   This is it in /lib/didactic\_clock/time\_keeper.rb

```ruby
module DidacticClock
  class TimeKeeper
    def verbose_time
      time = Time.now
      minute = time.min
      hour = time.hour % 12
      meridian_indicator = time.hour < 12 ? 'AM' : 'PM'
         
      "#{minute} minutes past #{hour} o'clock, #{meridian_indicator}"
    end
  end
end
```
    
   in the /bin/didactic\_clock\_server
    
```ruby
#!/usr/bin/env ruby

require 'sinatra'
require 'didactic_clock/time_keeper'

# otherwise sinatra won't always automagically launch its embedded 
# http server when this script is executed
set :run, true

get '/' do
  time_keeper = DidacticClock::TimeKeeper.new
  return time_keeper.verbose_time
end
```

## Contributing

1. Fork it

2. Create your feature branch (`git checkout -b my-new-feature`)

3. Commit your changes (`git commit -am 'Added some feature'`)

4. Push to the branch (`git push origin my-new-feature`)

5. Create new Pull Request
