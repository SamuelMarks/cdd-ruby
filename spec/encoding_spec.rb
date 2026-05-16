# frozen_string_literal: true

require_relative 'spec_helper'

class EncodingTest < Minitest::Test
  def test_encoding
    code = <<~RUBY
      # @request_body [Profile] multipart/form-data
      # @request_body_encoding multipart/form-data profileImage contentType:image/png style:form explode:true
      # @route POST /profile
      def post_profile
      end
    RUBY
    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Docstrings::Parser.parse(tokens, ir)

    op = ir.openapi_spec['paths']['/profile']['post']
    enc = op['requestBody']['content']['multipart/form-data']['encoding']['profileImage']
    assert_equal 'image/png', enc['contentType']
    assert_equal 'form', enc['style']
    assert_equal true, enc['explode']

    out = Cdd::Routes::Emitter.emit(ir)
    assert_match(
      %r{@request_body_encoding multipart/form-data profileImage contentType:image/png style:form explode:true}, out
    )
  end
end
