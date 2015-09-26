require File.expand_path('../spec_helper', __FILE__)

HIGHLIGHTERS = [
  :coderay,
  :pygments,
  :rouge,
  :ultraviolet
]

EXAMPLES = [
  {
    elements:  ['pre', 'code'],
    attribute: 'class',
    value:     'ruby',
    pattern:   /(?<lang>\w+)/,
    content:   '(1..10).reduce(&:+)'
  },
  {
    elements:  ['pre'],
    attribute: 'class',
    value:     'ruby',
    pattern:   /(?<lang>\w+)/,
    content:   '(1..10).reduce(&:+)'
  },
  {
    elements:  ['pre', 'code'],
    attribute: 'data-lang',
    value:     'ruby',
    pattern:   /(?<lang>\w+)/,
    content:   '(1..10).reduce(&:+)'
  },
  {
    elements:  ['pre', 'code'],
    attribute: 'class',
    value:     'language-ruby',
    pattern:   /language-(?<lang>\w+)/,
    content:   '(1..10).reduce(&:+)'
  }
]


describe Rack::Highlighter do

  let(:app) do
    create_app(status, headers, content, highlighter, options)
  end

  before do
    get '/'
  end

  describe 'with a content-type other than `text/html`' do

    let(:status) { 200 }
    let(:headers) do
      {
        'Content-Type'   => 'text/plain',
        'Content-Length' => content.length.to_s
      }
    end

    let(:content) { 'foobar' }
    let(:options) { {} }

    HIGHLIGHTERS.each do |lib|

      describe "when using #{lib}" do

        let(:highlighter) { lib }

        it 'leaves the status untouched' do
          last_response.status.must_equal status
        end

        it 'leaves the headers untouched' do
          last_response.headers.must_equal headers
        end

        it 'leaves the content untouched' do
          last_response.body.must_equal content
        end

      end

    end

  end

  describe 'with a content-type of `text/html`' do

    let(:status) { 200 }
    let(:headers) do
      {
        'Content-Type'   => 'text/html',
        'Content-Length' => content.length.to_s
      }
    end

    describe 'with a code block in the default format' do

      let(:content) do
        generate_example({
          elements:  ['pre', 'code'],
          attribute: 'class',
          value:     'ruby',
          content:   '(1..10).reduce(&:+)'
        })
      end
      let(:options) { {} }

      HIGHLIGHTERS.each do |lib|

        describe "when using #{lib}" do

          let(:highlighter) { lib }

          it 'leaves the status untouched' do
            last_response.status.must_equal status
          end

          it 'updates the headers with the new `Content-Length`' do
            last_response.headers['Content-Length'].wont_equal headers['Content-Length']
          end

          it 'modifies the content' do
            last_response.body.wont_equal content
          end

        end

      end

    end

    EXAMPLES.each do |example|

      describe "with a code block wrapped in `#{example[:elements].join(' > ')} #{example[:attribute]}=\"#{example[:value]}\"`" do

        let(:content) { generate_example(example) }
        let(:options) { example }

        HIGHLIGHTERS.each do |lib|

          describe "when using #{lib}" do

            let(:highlighter) { lib }

            it 'leaves the status untouched' do
              last_response.status.must_equal status
            end

            it 'updates the headers with the new `Content-Length`' do
              last_response.headers['Content-Length'].wont_equal headers['Content-Length']
            end

            it 'modifies the content' do
              last_response.body.wont_equal content
            end

          end

        end

      end

    end

  end

end
