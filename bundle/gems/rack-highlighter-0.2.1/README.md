# Rack::Highlighter [![Build Status](https://secure.travis-ci.org/unindented/rack-highlighter.png)](http://travis-ci.org/unindented/rack-highlighter) [![Dependency Status](https://gemnasium.com/unindented/rack-highlighter.png)](https://gemnasium.com/unindented/rack-highlighter)

Rack Middleware that provides syntax highlighting of code blocks, using the [CodeRay](http://rubygems.org/gems/coderay), [Pygments](http://rubygems.org/gems/pygments.rb), [Rouge](https://rubygems.org/gems/rouge) or [Ultraviolet](http://rubygems.org/gems/ultraviolet) gems.


## Installation

Add this line to your application's `Gemfile`:

```ruby
gem 'rack-highlighter'
```

And then execute:

```sh
$ bundle
```

Or install it yourself as:

```sh
$ gem install rack-highlighter
```


## Usage

### Adding highlighting to a Rails application

```ruby
require 'rack/highlighter'
require 'pygments'

class Application < Rails::Application
  config.middleware.use Rack::Highlighter, :pygments
end
```

### Adding highlighting to a Sinatra application

```ruby
require 'sinatra'
require 'rack/highlighter'
require 'pygments'

use Rack::Highlighter, :pygments

get('/') do
  '<pre><code class="ruby">puts "Hello world!"</code></pre>'
end
```

### Adding highlighting to a Rackup application

```ruby
require 'rack'
require 'rack/highlighter'
require 'pygments'

use Rack::Highlighter, :pygments

run lambda { |env|
  [200, {'Content-Type' => 'text/html'}, ['<pre><code class="ruby">puts "Hello world!"</code></pre>']]
}
```


## Highlighters

You can choose which highlighter to use. Just require the right gem, and specify it when invoking the middleware.

### CodeRay

```ruby
require 'rack/highlighter'
require 'coderay'

use Rack::Highlighter, :coderay
```

### Pygments

```ruby
require 'rack/highlighter'
require 'pygments'

use Rack::Highlighter, :pygments
```

### Rouge

```ruby
require 'rack/highlighter'
require 'rouge'

use Rack::Highlighter, :rouge
```

### Ultraviolet

```ruby
require 'rack/highlighter'
require 'uv'

use Rack::Highlighter, :ultraviolet
```


## Configuration

### Default

With the default options, `Rack::Highlighter` would recognize code blocks like the following:

```html
<pre>
  <code class="ruby">puts "Hello world!"</code>
</pre>
```

### Elements

If your code is wrapped in other tags, for example:

```html
<pre class="ruby">puts "Hello world!"</pre>
```

You can specify them in the `elements` option:

```ruby
use Rack::Highlighter, :pygments, { elements: ['pre'] }
```

### Attribute

If your block doesn't use the `class` attribute to declare the language of the code, for example:

```html
<pre>
  <code data-lang="ruby">puts "Hello world!"</code>
</pre>
```

You can specify it in the `attribute` option:

```ruby
use Rack::Highlighter, :pygments, { attribute: 'data-lang' }
```

### Pattern

If your block uses a certain pattern to declare the language of the code, for example:

```html
<pre>
  <code class="language-ruby">puts "Hello world!"</code>
</pre>
```

You can specify a regular expression to match it in the `pattern` option:

```ruby
use Rack::Highlighter, :pygments, { pattern: /language-(?<lang>\w+)/ }
```

The regular expression must have a capture group named `lang` for this to work.

### Additional parameters

You can pass additional parameters to the highlighter via the `misc` option:

```ruby
use Rack::Highlighter, :pygments, { misc: {linenos: 'inline'} }
```


## Meta

* Code: `git clone git://github.com/unindented/rack-highlighter.git`
* Home: <https://github.com/unindented/rack-highlighter/>


## Contributors

* Daniel Perez Alvarez ([unindented@gmail.com](mailto:unindented@gmail.com))


## License

Copyright (c) 2012 Daniel Perez Alvarez ([unindented.org](http://unindented.org/)). This is free software, and may be redistributed under the terms specified in the LICENSE file.
