class ApplicationController < Sinatra::Base

  if ENV.fetch("RACK_ENV") == "development"
    p "you're in #{__FILE__}"
  end

  # set folder for templates to ../views, but make the path absolute
  # set :views, File.expand_path('../../views', __FILE__)

  # don't enable logging when running tests
  configure :production, :development do
    enable :logging
  end

  # will be used to display 404 error pages
  not_found do
    erb :not_found
  end
end


=begin



Example 4-17. config.ru

require 'sinatra/base'
Dir.glob('./{helpers,controllers}/*.rb').each { |file| require file }

map('/example') { run ExampleController }
map('/') { run ApplicationController }

Rack will remove the path supplied to map from the request path and store it safely in env['SCRIPT_NAME']. Sinatra’s url helper will pick it up to construct correct links for you.
Dynamic Subclass Generation



Just like when creating constants, you may choose to use a different superclass to inherit from. Simply pass that class in as argument.

Example 4-19. Using a different superclass

require 'sinatra/base'

general_app = Sinatra.new { enable :logging }
custom_app = Sinatra.new(general_app) do
  get('/') { 'Hello World!' }
end

run custom_app

You can use this to dynamically generate new Sinatra applications.

Example 4-20. Dynamically generating Sinatra applications

require 'sinatra/base'

words = %w[foo bar blah]

words.each do |word|
  # generate a new application for each word
  map "/#{word}" { run Sinatra.new { get('/') { word } } }
end

map '/' do
  app = Sinatra.new do
    get '/' do
      list = words.map do |word|
        "<a href='/#{word}'>#{word}</a>"
      end
      list.join("<br>")
    end
  end

  run app
end

Better Rack Citizenship

In a typical scenario for modular applications, you usually embrace the usage of Rack: setting up different endpoints, creating your own middleware, and so on. If you want to use Sinatra in there as much as possible, you will have a hard time trying to only use a classic style application. If you decide to not only use Rack to communicate to the web server, but also internally to achieve a modular and flexible architecture, Sinatra will try to help you wherever possible.

In return it will give you interoperability and open up a variety of already existing libraries and middleware, just waiting for you to use them.
Chaining Classes

We already talked about using map to serve more than one Sinatra application from the same Rack handler. But this is not the only way to combine multiple apps.
Middleware Chain

If you followed along in Chapter 3 closely, you might have arrived at this next point intuitively. We demonstrated how to use a Sinatra application as middleware. You are certainly free to use one Sinatra application as middleware in front of another Sinatra application. This will first try to find a route in the middleware application, and if that middleware application does not find a matching route, it will hand the request on to the other application, as shown in Example 4-21.

Example 4-21. Using Sinatra as endpoint and middleware

require 'sinatra/base'

class Foo < Sinatra::Base
  get('/foo') { 'foo' }
end

class Bar < Sinatra::Base
  get('/bar') { 'bar' }

  use Foo
  run!
end

This allows us to create a slightly different class architecture, where classes are not responsible for a specific set of paths, but instead may define any routes. If we combine this with Ruby’s inherited hook for automatically tracking subclass creation (as in Example 4-22), we don’t even have to keep a list of classes around.

Example 4-22. Automatically picking up subclasses as middleware

require 'sinatra/base'

class ApplicationController < Sinatra::Base
  def self.inherited(sublass)
    super
    use sublass
  end

  enable :logging
end

class ExampleController < Sinatra::Base
  get('/example') { "Example!" }
end

# works with dynamically generated applications, too
Sinatra.new ApplicationController do
  get '/' do
    "See the <a href='/example'>example</a>."
  end
end

ApplicationController.run!

Caution

If you define inherited on a Ruby class, always make sure you call super. Sinatra uses inherited, too, in order to set up a new application class properly. If you skip the super call, the class will not be set up properly.
Cascade

There is an alternative that seems rather similar at first glance: using a cascade rather than a middleware chain. It works pretty much the same. You supply a list of Rack application, which will be tried one after the other, and the first result that doesn’t have a status code of 404 will be returned. For a basic demonstration, Example 4-23 will behave exactly like a middleware chain.

Example 4-23. Using Rack::Cascade with rackup

require 'sinatra/base'

class Foo < Sinatra::Base
  get('/foo') { 'foo' }
end

class Bar < Sinatra::Base
  get('/bar') { 'bar' }
end

run Rack::Cascade, [Foo, Bar]

There are a few minor differences to using middleware. First of all, the behavior of passing on the request if no route matches is Sinatra specific. With a cascade, you can use any endpoints; you might first try a Rails application and a Sinatra application after that. Moreover, imagine you explicitly return a 404 error from a Sinatra application, for instance with get('/') { not_found }. If you do that in a middleware and the route matches, the request will never be handed on to the second application; with a cascade, it will be. See Example 4-24 for a concrete implementation of this concept.

Example 4-24. Handing on a request with not_found

require 'sinatra/base'

class Foo1 < Sinatra::Base
  get('/foo') { not_found }
end

class Foo2 < Sinatra::Base
  get('/foo') { 'foo #2' }
end

run Rack::Cascade, [Foo1, Foo2]

Note

If you happen to have a larger number of endpoints, using a cascade is likely to result in better performance, at least on the official Ruby implementation.

Ruby uses a Mark-And-Sweep Garbage Collector to remove objects from memory that are no longer needed (usually it’s just called the GC), which will walk through all stack frames to mark objects that are not supposed to be removed. Since a middleware chain is a recursive structure, each middleware will add at least one stack frame, increasing the amount of work the GC has to deal with.

Since Ruby’s GC also is a Stop-The-World GC, your Ruby process will not be able to do anything else while it is collecting garbage.
With a Router

A third option is using a Rack router. We’ve already used the most simple router a few times: Rack::URLMap. It ships with the rack gem and is used by Rack under the hood for its map method. However, there are a lot more routers out there for Rack with different capabilities and characteristics. In a way, Sinatra is a router, too, or at least can be used as such, but more on that later.

A router is similar to a Rack middleware. The main difference is that it doesn’t wrap a single Rack endpoint, but keeps a list of endpoints, just like Rack::Cascade does. Depending on some criteria, usually the requested path, the router will then decide what endpoint to hand the request to. This is basically the same thing Sinatra does, except that it doesn’t hand off the request. Instead, it decides what block of code to evaluate.

Most routers differ in the way they decide which endpoint to hand the request to. All routers meant for general usage do offer routing based on the path, but how complex their path matching might be varies. While Rack::URLMap only matches prefixes, most other routers allow simple wildcard matching. Both Rack::Mount, which is used by Rails, and Sinatra allow arbitrary matching logic.

However, such flexibility comes at a price: Rack::Mount and Sinatra have a routing complexity of O(n), meaning that in the worst-case scenario an incoming request has to be matched against all the defined routes. Usually this doesn’t matter much, though. We did some experiments replacing the Sinatra routing logic with a less capable version, that does routing in O(1), and we didn’t see any performance benefits for applications with fewer than about 10,000 routes.

Rack::Mount is known to produce fast routing, however its API is not meant to be used directly but rather by other libraries, like the Rails routes DSL. Install it by running gem install rack-mount. Example 4-25 demonstrates how to use it.

Example 4-25. Using Rack::Mount in a config.ru

require 'sinatra/base'
require 'rack/mount'

class Foo < Sinatra::Base
  get('/foo') { 'foo' }
end

class Bar < Sinatra::Base
  get('/bar') { 'bar' }
end

Routes = Rack::Mount::RouteSet.new do |set|
  set.add_route Foo, :path_info => %r{^/foo$}
  set.add_route Bar, :path_info => %r{^/bar$}
end

run Routes

It also supports other criteria besides the path. For instance, you can easily send different HTTP methods to different endpoints, as in Example 4-26.

Example 4-26. Route depending on the verb

require 'sinatra/base'
require 'rack/mount'

class Get < Sinatra::Base
  get('/') { 'GET!' }
end

class Post < Sinatra::Base
  post('/') { 'POST!' }
end

Routes = Rack::Mount::RouteSet.new do |set|
  set.add_route Get,  :request_method => 'GET'
  set.add_route Post, :request_method => 'POST'
end

run Routes

On Return Values

The application’s return value is an integral part of the Rack specification. Rack is picky on what you may return. Sinatra, on the other hand, is forgiving when it comes to return values. Sinatra routes commonly have a string value returned on the last line of the block, but it can also be any value conforming to the Rack specification. Example 4-27 demonstrates this.

Example 4-27. Running a Rack application with Sinatra

require 'sinatra'

# this is a valid Rack program
MyApp = proc { [200, {'Content-Type' => 'text/plain'}, ['ok']] }

# that you can run with Sinatra
get('/', &MyApp)

Besides strings and Rack arrays, it accepts a wide range of return values that look nearly like Rack return values. As the body object can be a string, you don’t have to wrap it in an array. You don’t have to include a headers hash either. Example 4-28 clarifies this point.

Example 4-28. Alternative return values

require 'sinatra'

get('/') { [418, "I'm a tea pot!"] }

You can also push a return value through the wire any time using the halt helper, like in Example 4-29.

Example 4-29. Alternative return values

require 'sinatra'

get '/' do
  halt [418, "I'm a tea pot!"]
  "You'll never get here!"
end

With halt you can pass the array elements as separate arguments. This helper is especially useful in filters (as in Example 4-30), where you can use it to directly send the response.

Example 4-30. Alternative return values

require 'sinatra'

before { halt 418, "I'm a tea pot!" }
get('/') { "You'll never get here!" }

Using Sinatra as Router

Since Sinatra accepts Rack return values, you can use the return value of another Rack endpoint, as shown in Example 4-31. Remember: all Rack applications respond to call, which takes the env hash as argument.

Example 4-31. Using another Rack endpoint in a route

require 'sinatra/base'

class Foo < Sinatra::Base
  get('/') { "Hello from Foo!" }
end

class Bar < Sinatra::Base
  get('/') { Foo.call(env) }
end

Bar.run!

We can easily use this to implement a Rack router. Let’s implement Rack::Mount from Example 4-31 with Sinatra instead, as shown in Example 4-32.

Example 4-32. Using Sinatra as router

require 'sinatra/base'

class Foo < Sinatra::Base
  get('/foo') { 'foo' }
end

class Bar < Sinatra::Base
  get('/bar') { 'bar' }
end

class Routes < Sinatra::Base
  get('/foo') { Foo.call(env) }
  get('/bar') { Bar.call(env) }
end

run Routes

And of course, we can also implement the method-based routing easily, as shown in Example 4-33.

Example 4-33. Verb based routing with Sinatra

require 'sinatra/base'

class Get < Sinatra::Base
  get('/') { 'GET!' }
end

class Post < Sinatra::Base
  post('/') { 'POST!' }
end

class Routes < Sinatra::Base
  get('/') { Get.call(env) }
  post('/') { Post.call(env) }
end

run Routes

Extensions and Modular Applications

Let’s recall the two common ways to extend Sinatra applications: extensions and helpers. Both are usable just the way they are in classic applications. However, let’s take a closer look at them again.
Helpers

Helpers are instance methods and therefore available both in route blocks and views. We can still use the helpers method to import methods from a module or to pass a block with methods to it, just the way we did in Chapter 3. See Example 4-34.

Example 4-34. Using helpers in a modular application

require 'sinatra/base'
require 'date'

module MyHelpers
  def time
    Time.now.to_s
  end
end

class MyApplication < Sinatra::Base
  helpers MyApplication

  helpers do
    def date
      Date.today.to_s
    end
  end

  get('/') { "it's #{time}\n" }
  get('/today') { "today is #{date}\n" }

  run!
end

However, in the end, those methods will become normal instance methods, so there is actually no need to define them specially. See Example 4-35.

Example 4-35. Helpers are just instance methods

require 'sinatra/base'

class MyApplication < Sinatra::Base
  def time
    Time.now.to_s
  end

  get('/') { "it's #{time}\n" }
  run!
end

Extensions

Extensions generally add DSL methods used at load time, just like get, before, and so on. Just like helpers, those can be defined on the class directly. See Example 4-36 for a demonstration of using class methods.

Example 4-36. Using class methods

require 'sinatra/base'

class MyApplication < Sinatra::Base
  def self.get_and_post(*args, &block)
    get(*args, &block)
    post(*args, &block)
  end

  get_and_post '/' do
    "Thanks for your #{request.request_method} request."
  end

  run!
end

Previously, we introduced a common pattern for reusable extensions: you call Sinatra.register Extension in the file defining the extension, you just have to require that file, and it will work automatically. This is only true for classic applications, we still have to register the extension explicitly in modular applications, as seen in Example 4-37.

Example 4-37. Extensions and modular applications

require 'sinatra/base'
module Sinatra
  module GetAndPost
    def get_and_post(*args, &block)
      get(*args, &block)
      post(*args, &block)
    end
  end

  # this will only affect Sinatra::Application
  register GetAndPost
end

class MyApplication < Sinatra::Base
  register Sinatra::GetAndPost

  get_and_post '/' do
    "Thanks for your #{request.request_method} request."
  end

  run!
end

Why this overhead? Automatically registering extensions for modular applications is not as appealing as it might appear at first glance. Modular applications usually travel in packs: if one application loads an extension, you don’t want to drag that extension into other application classes by accident.
Summary

We introduced modular applications in this chapter, which allows us to easily build more complex and flexible architectures. We discussed how to run and combine such applications and while doing so, learned a few more things about Rack.
=end