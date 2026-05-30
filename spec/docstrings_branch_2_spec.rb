# frozen_string_literal: true

require_relative 'spec_helper'

class DocstringsBranchTest4 < Minitest::Test
  def test_even_more
    code = <<~RUBY
      # @param_example_ref q2 MyExample MyRef
      # @request_body_example_ref application/xml MyExample MyRef
      # @response_example_ref 200 application/xml MyExample MyRef
      # @response_example_ref 404 application/json MyExample MyRef
      # @op_server_var http://server.com missing default
      # @route GET /examples_missing
      # @param q [string] in:query
      # @request_body [string] application/json
      # @response 200 [string] application/json
      # @op_server http://server.com
    RUBY
    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Docstrings::Parser.parse(tokens, ir)
  end

  def test_request_body_encoding_missing
    code = <<~RUBY
      # @request_body_encoding application/json myProp
      # @route GET /rb_enc_missing

      # @request_body [string] application/json
      # @request_body_encoding application/json myProp missingBool:false missingString:hello
      # @route GET /rb_enc
    RUBY
    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Docstrings::Parser.parse(tokens, ir)
  end

  def test_headers_and_links
    code = <<~RUBY
      # @response_header 200 X-MyHead [integer] someBool:false someString:hello
      # @link 200 MyLink parameters.id:123
      # @link 200 MyLink2 someBool:false someString:hello
      # @route GET /headers_links
    RUBY
    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Docstrings::Parser.parse(tokens, ir)
  end

  def test_responses_boolean
    code = <<~RUBY
      # @response 200 [MySchema] application/json desc:hello boolFal:false stringVal:str
      # @response 400 desc:hello boolFal:false stringVal:str
      # @route GET /resp_bool
    RUBY
    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Docstrings::Parser.parse(tokens, ir)
  end

  def test_callback_response_no_callback
    code = <<~RUBY
      # @callback_request_body [string] application/json desc
      # @callback_response 200 [string] application/json desc

      # @callback MyCb {$request.query.url} post
      # @callback_request_body [string] application/json desc
      # @callback_response 200 [string] application/json desc someBool:false someString:hello
      # @callback_response 400 desc someBool:false someString:hello
      # @route GET /missing_cb
    RUBY
    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Docstrings::Parser.parse(tokens, ir)
  end
end
