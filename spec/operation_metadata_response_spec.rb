# frozen_string_literal: true

require_relative 'spec_helper'

class OperationMetadataResponseTest < Minitest::Test
  def test_response_metadata
    code = <<~RUBY
      # @response 200 [User] application/json required:true A successful response
      # @route GET /response
      def get_response
      end
    RUBY
    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Docstrings::Parser.parse(tokens, ir)

    op = ir.openapi_spec['paths']['/response']['get']

    resp = op['responses']['200']
    assert_equal 'A successful response', resp['description']
    assert_equal true, resp['content']['application/json']['required']
    assert_equal '#/components/schemas/User', resp['content']['application/json']['schema']['$ref']

    out = Cdd::Routes::Emitter.emit(ir)
    assert_match(%r{@response 200 \[User\] application/json required:true A successful response}, out)
  end

  def test_response_with_options
    code = <<~RUBY
      # @response 200 [Success] application/json description:Success response true_val:true false_val:false
      # @route POST /resp_opts
      def resp_opts
      end
    RUBY
    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Docstrings::Parser.parse(tokens, ir)

    op = ir.openapi_spec['paths']['/resp_opts']['post']
    resp = op['responses']['200']
    assert_equal 'Success response', resp['description']
    assert_equal true, resp['content']['application/json']['true_val']
    assert_equal false, resp['content']['application/json']['false_val']
  end

  def test_response_no_media_type_with_options
    code = <<~RUBY
      # @response 400 description:Bad request true_val:true false_val:false
      # @route GET /resp_opts2
      def resp_opts2
      end
    RUBY
    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Docstrings::Parser.parse(tokens, ir)

    op = ir.openapi_spec['paths']['/resp_opts2']['get']
    resp = op['responses']['400']
    assert_equal 'Bad request', resp['description']
    assert_equal true, resp['true_val']
    assert_equal false, resp['false_val']
  end
end
