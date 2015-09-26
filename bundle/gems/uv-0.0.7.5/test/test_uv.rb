require 'rubygems'
require 'test/unit'

$LOAD_PATH.unshift File.join(File.dirname(__FILE__), '..', 'lib')

require 'uv'

class UvTest < Test::Unit::TestCase

  Uv.debug=false

  def test_parses_blank
    assert_equal %(<pre class="mac_classic"></pre>), Uv.parse('', 'xhtml', 'css')
    assert_equal %(<pre class="mac_classic"></pre>), Uv.parse('', 'xhtml', 'bad_extension')
  end

  def test_init_syntaxes
    assert_include Uv.init_syntaxes.keys, 'css'
  end

  def test_debugs
    assert_kind_of Textpow::DebugProcessor, Uv.debug('', 'css')
  end

  def test_find_syntaxes_by_ext
    assert_instance_of Array, Uv.find_syntaxes_by_ext("css")
    assert_instance_of Textpow::SyntaxNode, Uv.find_syntaxes_by_ext("css").first
    assert_equal "CSS", Uv.find_syntaxes_by_ext("css").first.name
  end

  def test_find_syntaxes
    assert_equal "Plain Text", Uv.find_syntaxes(["not_a_syntax_ext"]).first.name
    assert_equal "Plain Text", Uv.find_syntaxes(['']).first.name
    assert_equal "Plain Text", Uv.find_syntaxes([]).first.name
  end

end
