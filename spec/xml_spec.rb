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
      'xml' => {
        'name' => 'user',
        'attribute' => true,
        'wrapped' => false,
        'prefix' => 'ex',
        'namespace' => 'http://example.com/schema'
      }
    }

    out = Cdd::Classes::Emitter.emit(ir)
    assert_match(
      %r{@schema_xml User name:user attribute:true wrapped:false prefix:ex namespace:http://example.com/schema}, out
    )
  end
end
