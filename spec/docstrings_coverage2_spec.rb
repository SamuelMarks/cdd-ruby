# frozen_string_literal: true

require_relative 'spec_helper'

class DocstringsCoverage2Test < Minitest::Test
  def test_docstrings_missing_branches_true
    code = <<~RUBY
      # @security BearerAuth my_scope
      # @callback cb cb_url get
      # @callback_request_body [CbBody] application/json desc
      # @callback_response 200 [CbResp] application/json desc
      # @response 200 [MyResp] application/json x-custom:string_val
      # @external_docs https://example.com ext_desc
      # @op_server https://op.example.com op_desc
      # @route GET /missing
      def some_method
      end

      # @request_body [MyBody] application/json encoding:myProp
      # @request_body_encoding myProp application/json explode:true another:stringval
      # @route POST /missing_encoding
      def missing_encoding_method
      end

      # @callback_response 200 [CbResp] application/json description:some_desc opt:stringval
      # @route POST /missing_cb_desc
      def missing_cb_desc
      end
    RUBY

    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Docstrings::Parser.parse(tokens, ir)
  end

  def test_docstrings_missing_branches_false
    code = <<~RUBY
      # @security
      # @callback cb cb_url get
      # @callback_request_body [CbBody] application/json
      # @callback_response 200 [CbResp] application/json
      # @response 200 [MyResp] application/json
      # @external_docs https://example.com
      # @op_server https://op.example.com
      # @route GET /missing_false
      def some_method
      end
    RUBY

    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Docstrings::Parser.parse(tokens, ir)
  end

  def test_docstrings_components
    code = <<~RUBY
      # @component_callback_response 200 [CbResp] application/json description:some_desc opt:stringval opt2:false
      # @component_response MyResp description:some_desc opt:stringval opt2:false

      # @request_body [MyBody] application/json encoding:myProp
      # @request_body_encoding application/json myProp explode:true another:stringval My encoding desc
      # @route POST /missing_encoding_desc
      def missing_encoding_desc
      end
    RUBY
    ir = Cdd::IR.new
    # need a callback definition first for component_callback_response
    ir.openapi_spec['components'] = { 'callbacks' => { 'cb' => { 'cb_url' => { 'get' => { 'responses' => {} } } } } }
    tokens = Ripper.lex(code)
    Cdd::Docstrings::Parser.parse(tokens, ir)
  end
end
