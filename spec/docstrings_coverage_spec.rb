# frozen_string_literal: true

require_relative 'spec_helper'

class DocstringsCoverageTest < Minitest::Test
  def test_docstrings_coverage
    code = <<~RUBY
      # @component_param my_p1 [CustomType1] in:query b:false c:true
      # @component_request_body MyRb [MySchema1] application/json b:false c:true description:test
      # @component_header MyHeader [CustomType2] b:false c:true description:test
      
      # @component_callback MyCb url post
      # @component_callback_response 200 [CustomType3] application/json b:false c:true description:test
      
      # @component_response MyResp [CustomType4] application/json b:false c:true description:test
      
      # @param p2 [CustomType5] in:query b:false c:true
      # @response_header 200 myHeader [CustomType6] b:false c:true description:test
      # @route GET /test
      def test_route
      end
    RUBY

    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Docstrings::Parser.parse(tokens, ir)

    p1 = ir.openapi_spec['components']['parameters']['my_p1']
    assert_equal '#/components/schemas/CustomType1', p1['schema']['$ref']
    assert_equal false, p1['b']
    assert_equal true, p1['c']

    rb = ir.openapi_spec['components']['requestBodies']['MyRb']
    assert_equal false, rb['b']
    assert_equal true, rb['c']

    h = ir.openapi_spec['components']['headers']['MyHeader']
    assert_equal '#/components/schemas/CustomType2', h['schema']['$ref']
    assert_equal false, h['b']
    assert_equal true, h['c']
    
    cb_resp = ir.openapi_spec['components']['callbacks']['MyCb']['url']['post']['responses']['200']
    assert_equal false, cb_resp['content']['application/json']['b']
    assert_equal true, cb_resp['content']['application/json']['c']

    resp = ir.openapi_spec['components']['responses']['MyResp']
    assert_equal false, resp['content']['application/json']['b']
    assert_equal true, resp['content']['application/json']['c']

    op = ir.openapi_spec['paths']['/test']['get']
    
    p2 = op['parameters'].first
    assert_equal '#/components/schemas/CustomType5', p2['schema']['$ref']
    assert_equal false, p2['b']
    assert_equal true, p2['c']

    rh = op['responses']['200']['headers']['myHeader']
    assert_equal '#/components/schemas/CustomType6', rh['schema']['$ref']
    assert_equal false, rh['b']
    assert_equal true, rh['c']
  end
end

class DocstringsCoverageWithoutSchemaTest < Minitest::Test
  def test_docstrings_coverage_no_schema
    code = <<~RUBY
      # @component_callback MyCb url post
      # @component_callback_response 200 b:false c:true
      
      # @component_response MyResp b:false c:true
      # @route GET /test
      def test_route
      end
    RUBY

    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Docstrings::Parser.parse(tokens, ir)

    cb_resp = ir.openapi_spec['components']['callbacks']['MyCb']['url']['post']['responses']['200']
    assert_equal false, cb_resp['b']
    assert_equal true, cb_resp['c']

    resp = ir.openapi_spec['components']['responses']['MyResp']
    assert_equal false, resp['b']
    assert_equal true, resp['c']
  end
end

class DocstringsCoverageEmitTest < Minitest::Test
  def test_emit_coverage
    code = <<~RUBY
      # @component_response MyResp [CustomType4] application/json required:true description:test
      # @route GET /test
      def test_route
      end
    RUBY

    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Docstrings::Parser.parse(tokens, ir)

    out = Cdd::Routes::Emitter.emit(ir)
    assert_match(/required:true/, out)
  end
end
