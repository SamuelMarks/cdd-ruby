# frozen_string_literal: true

require_relative 'spec_helper'

class XmlTest < Minitest::Test
  def test_schema_xml
    code = <<~RUBY
      # @schema User
      # @schema_xml User name:user attribute:true prefix:ex namespace:http://example.com/schema wrapped:false
      def dummy
      end
    RUBY
    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Docstrings::Parser.parse(tokens, ir)

    schema = ir.openapi_spec['components']['schemas']['User']
    assert schema['xml']
    assert_equal 'user', schema['xml']['name']
    assert_equal true, schema['xml']['attribute']
    assert_equal false, schema['xml']['wrapped']
    assert_equal 'ex', schema['xml']['prefix']
    assert_equal 'http://example.com/schema', schema['xml']['namespace']
  end

  def test_emit_schema_xml
    ir = Cdd::IR.new
    ir.openapi_spec['components']['schemas']['User'] = {
      'type' => 'object',
      'readOnly' => true,
      'properties' => {
        'id' => { 'type' => 'integer', 'readOnly' => true }
      },
      'xml' => {
        'name' => 'user',
        'attribute' => true,
        'nodeType' => 'element',
        'wrapped' => false,
        'prefix' => 'ex',
        'namespace' => 'http://example.com/schema'
      }
    }

    out = Cdd::Classes::Emitter.emit(ir)
    assert_match(
      %r{@schema_xml User name:user attribute:true nodeType:element wrapped:false prefix:ex namespace:http://example.com/schema},
      out
    )
    assert_includes out, '# @readonly id'

    ir2 = Cdd::IR.new
    tokens = Ripper.lex(out)
    Cdd::Classes::Parser.parse(tokens, ir2)
    Cdd::Docstrings::Parser.parse(tokens, ir2)
    assert_equal true, ir2.openapi_spec.dig('components', 'schemas', 'User', 'readOnly')
    assert_equal true, ir2.openapi_spec.dig('components', 'schemas', 'User', 'properties', 'id', 'readOnly')
    assert_equal 'element', ir2.openapi_spec.dig('components', 'schemas', 'User', 'xml', 'nodeType')
  end
end
