require 'minitest/autorun'
require 'minitest/reporters'
require 'rack/test'

require 'coderay'
require 'pygments'
require 'rouge'
require 'uv'

require File.expand_path('../../lib/rack/highlighter', __FILE__)

include Rack::Test::Methods

MiniTest::Reporters.use! MiniTest::Reporters::SpecReporter.new


def create_app(status, headers, content, highlighter, options)
  app = lambda { |env| [status, headers, [content]] }
  Rack::Highlighter.new(app, highlighter, options)
end

def generate_example(args)
  elements  = args[:elements].clone
  attribute = args[:attribute]
  value     = args[:value]
  content   = args[:content]

  doc = Nokogiri::HTML::DocumentFragment.parse('')
  current = doc

  until elements.empty?
    tmp = Nokogiri::XML::Node.new(elements.shift, doc)
    if elements.empty?
      tmp[attribute] = value
      tmp.content = content
    end

    current << tmp
    current = tmp
  end

  doc.to_html
end

def generate_example_with(klass, content, &block)
  doc.to_html
end
