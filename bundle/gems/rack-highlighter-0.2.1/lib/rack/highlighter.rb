require 'rack/highlighter/version'

require 'rack'
require 'nokogiri'
require 'htmlentities'

module Rack
  class Highlighter
    include Rack::Utils

    DEFAULT_LANG = 'text'

    DEFAULT_OPTS = {
      elements:  ['pre', 'code'],
      attribute: 'class',
      pattern:   /(?<lang>\w+)/,
      misc:      {}
    }

    def initialize(app, highlighter, opts = {})
      @app = app
      @highlighter = highlighter
      @coder = ::HTMLEntities.new
      @opts = DEFAULT_OPTS.merge(opts)
    end

    def call(env)
      status, headers, response = @app.call(env)
      headers = HeaderHash.new(headers)

      if should_highlight?(status, headers)
        content = extract_content(response)

        doc = ::Nokogiri::HTML(content)
        search_for_nodes(doc).each { |node| highlight_node(node) }
        content = doc.to_html

        headers['content-length'] = bytesize(content).to_s
        response = [content]
      end

      [status, headers, response]
    end

    private

    def should_highlight?(status, headers)
      !STATUS_WITH_NO_ENTITY_BODY.include?(status) &&
         !headers['transfer-encoding'] &&
          headers['content-type'] &&
          headers['content-type'].include?('text/html')
    end

    def extract_content(response)
      content = ''
      response.each { |part| content += part }
      content
    end

    def search_for_nodes(doc)
      doc.search(@opts[:elements].join('>'))
    end

    def highlight_node(node)
      lang = extract_lang(node)
      code = @coder.decode(extract_html(node))

      target = node
      (@opts[:elements].length - 1).times { target = target.parent }

      # Gotta clone the options, some misbehaving library could modify it.
      target.swap(send(@highlighter, lang, code, @opts[:misc].clone))
    end

    def extract_lang(node)
      attr = node[@opts[:attribute]]
      ((attr && @opts[:pattern].match(attr)) || { lang: DEFAULT_LANG })[:lang]
    end

    def extract_html(node)
      node.inner_html
    end

    def coderay(lang, code, options)
      ::CodeRay.scan(code, lang).div(options)
    end

    def pygments(lang, code, options)
      ::Pygments.highlight(code, formatter: 'html', lexer: lang, options: options)
    end

    def rouge(lang, code, options)
      lexer = ::Rouge::Lexer.find_fancy(lang, code) || ::Rouge::Lexers::Text
      formatter = ::Rouge::Formatters::HTML.new(options)
      formatter.format(lexer.lex(code))
    end

    def ultraviolet(lang, code, options)
      ::Uv.parse(code, 'xhtml', lang, options[:lines], options[:theme])
    end

  end
end
