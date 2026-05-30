# frozen_string_literal: true

require_relative 'spec_helper'

class DocstringsBranchTest < Minitest::Test
  def test_docstrings_parse_branches
    code = <<~RUBY
      # This is a random comment that doesn't match any tag

      # @server_var http://missing.url myVar defaultVal

      # @server http://exists.url
      # @server_var http://exists.url myVar defaultVal enum:a,b

      # @server http://exists2.url
      # @server_var http://exists2.url myVar2 defaultVal some description

      # @security_scheme EmptyDesc apiKey name:k in:header

      # @schema_xml MySchema name:foo bad_rest
      # @schema_xml MySchema2 name:foo

      # @schema_any_of NoMapping Ref1 discriminator:type
      # @schema_any_of WithDefault Ref1 discriminator:type mapping:A:RefA defaultMapping:RefDef

      # @schema_one_of NoMapping1 Ref1 discriminator:type
      # @schema_one_of WithDefault1 Ref1 discriminator:type mapping:A:RefA defaultMapping:RefDef
    RUBY
    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Docstrings::Parser.parse(tokens, ir)
  end

  def test_docstrings_component_tags
    code = <<~RUBY
      # @callback_request_body [MySchema] application/json

      # @component_param MyParam [integer] in:query description:desc
      # @component_param MyParam2 [integer] in:query required:true allowEmptyValue:false stringParam:hello

      # @component_request_body MyRb [MySchema] application/json description:desc
      # @component_request_body MyRb2 [MySchema] application/json required:true someBool:false someString:hello

      # @component_response MyResp [MySchema] application/json description:desc
      # @component_response MyResp2 [MySchema] application/json someBool:false someString:hello

      # @component_header MyHeader [string] description:desc
      # @component_header MyHeader2 [string] required:true someBool:false someString:hello

      # @component_link MyLink operationId:op
      # @component_link MyLink2 operationId:op someBool:false someString:hello

      # @component_callback MyCb {$request.query.url} post
      # @component_callback_response 200 [MySchema] application/json
      # @component_callback_response 400 someBool:false someString:hello

      # @component_callback_request_body [MySchema] application/json
      # @component_callback_request_body [MySchema] application/json desc

      # @route GET /myroute
      # @param q [string] in:query
      # @request_header X-Custom [string]
      # @response_header 200 X-Resp [string]
      # @link 200 MyLink operationId:op someString:hello
      # @request_body [MySchema] application/json
      # @response 200 [MySchema] application/json

      # @route_ref http://myurl myroute

      # @openapi_info title:MyTitle version:1.0.0 someBool:false someString:hello
      # @openapi_contact name:Me url:http://me.com email:me@me.com someBool:false someString:hello
      # @openapi_license name:MIT url:http://mit.edu someBool:false someString:hello
      # @openapi_external_docs url:http://docs.com description:Docs someBool:false someString:hello
      # @openapi_server http://myserver.com description:Server someBool:false someString:hello
    RUBY
    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Docstrings::Parser.parse(tokens, ir)

    code2 = <<~RUBY
      # @component_callback_request_body [MySchema] application/json
      # @component_callback_response 200 [MySchema] application/json
    RUBY
    ir2 = Cdd::IR.new
    tokens2 = Ripper.lex(code2)
    Cdd::Docstrings::Parser.parse(tokens2, ir2)
  end

  def test_component_callback_response_no_media
    code = <<~RUBY
      # @component_callback MyCb {$request.query.url} post
      # @component_callback_response 200 someBool:false someString:hello
    RUBY
    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Docstrings::Parser.parse(tokens, ir)
  end

  def test_example_refs_without_targets
    code = <<~RUBY
      # @param_example_ref q MyExample MyRef
      # @request_body_example_ref application/json MyExample MyRef
      # @response_example_ref 200 application/json MyExample MyRef
      # @route GET /examples_missing
      # @param q [string] in:query
      # @response 200 [string] application/json
    RUBY
    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Docstrings::Parser.parse(tokens, ir)
  end
end
