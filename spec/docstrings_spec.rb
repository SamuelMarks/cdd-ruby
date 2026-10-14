# frozen_string_literal: true

require_relative 'spec_helper'

class DocstringsTest < Minitest::Test
  def test_advanced_docstrings
    code = <<~RUBY
      # @server https://api.example.com Production server

      # @schema User
      class User
      end

      # @param id [integer] in:path required:true User ID
      # @request_body [User] application/json Create User
      # @response 201 [User] application/json User created
      # @route POST /users/{id}
      def create_user
      end
    RUBY

    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Docstrings::Parser.parse(tokens, ir)

    assert_equal 1, ir.openapi_spec['servers'].size
    assert_equal 'https://api.example.com', ir.openapi_spec['servers'][0]['url']

    assert ir.openapi_spec['components']['schemas'].key?('User')

    op = ir.openapi_spec['paths']['/users/{id}']['post']
    assert op.key?('parameters')
    assert_equal 'id', op['parameters'][0]['name']
    assert_equal 'path', op['parameters'][0]['in']
    assert_equal true, op['parameters'][0]['required']

    assert op.key?('requestBody')
    assert_equal 'application/json', op['requestBody']['content'].keys.first
    assert_equal '#/components/schemas/User', op['requestBody']['content']['application/json']['schema']['$ref']

    assert op.key?('responses')
    assert op['responses'].key?('201')
    assert_equal 'User created', op['responses']['201']['description']
  end

  def test_docstrings_parse_custom_type_parameter
    ir = Cdd::IR.new
    ir.openapi_spec = {}
    tokens = Ripper.lex(<<~RUBY)
      # @param name [CustomType] in:query description
      # @route GET /test
      def test_route; end
    RUBY
    Cdd::Docstrings::Parser.parse(tokens, ir)
    schema = ir.openapi_spec['paths']['/test']['get']['parameters'][0]['schema']
    assert_equal '#/components/schemas/CustomType', schema['$ref']
  end

  def test_docstrings_servers_xml_and_composition_schemas
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
    assert_equal 'foo', ir.openapi_spec.dig('components', 'schemas', 'MySchema', 'xml', 'name')
  end

  def test_docstrings_component_and_operation_tags
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
    assert ir.openapi_spec.dig('components', 'parameters', 'MyParam')

    code2 = <<~RUBY
      # @component_callback_request_body [MySchema] application/json
      # @component_callback_response 200 [MySchema] application/json
    RUBY
    ir2 = Cdd::IR.new
    Cdd::Docstrings::Parser.parse(Ripper.lex(code2), ir2)

    code3 = <<~RUBY
      # @component_callback MyCb {$request.query.url} post
      # @component_callback_response 200 someBool:false someString:hello
    RUBY
    ir3 = Cdd::IR.new
    Cdd::Docstrings::Parser.parse(Ripper.lex(code3), ir3)
  end

  def test_docstrings_example_refs_and_operation_details
    code = <<~RUBY
      # @param_example_ref q MyExample MyRef
      # @request_body_example_ref application/json MyExample MyRef
      # @response_example_ref 200 application/json MyExample MyRef
      # @route GET /examples_unmatched
      # @param q [string] in:query
      # @response 200 [string] application/json
    RUBY
    ir = Cdd::IR.new
    Cdd::Docstrings::Parser.parse(Ripper.lex(code), ir)

    code2 = <<~RUBY
      # @param_example_ref q2 MyExample MyRef
      # @request_body_example_ref application/xml MyExample MyRef
      # @response_example_ref 200 application/xml MyExample MyRef
      # @response_example_ref 404 application/json MyExample MyRef
      # @op_server_var http://server.com missing default
      # @route GET /examples_mismatched
      # @param q [string] in:query
      # @request_body [string] application/json
      # @response 200 [string] application/json
      # @op_server http://server.com

      # @request_body_encoding application/json myProp
      # @route GET /rb_enc_no_body

      # @request_body [string] application/json
      # @request_body_encoding application/json myProp optBool:false optString:hello
      # @route GET /rb_enc

      # @response_header 200 X-MyHead [integer] someBool:false someString:hello
      # @link 200 MyLink parameters.id:123
      # @link 200 MyLink2 someBool:false someString:hello
      # @route GET /headers_links

      # @response 200 [MySchema] application/json desc:hello boolFal:false stringVal:str
      # @response 400 desc:hello boolFal:false stringVal:str
      # @route GET /resp_bool

      # @callback_request_body [string] application/json desc
      # @callback_response 200 [string] application/json desc

      # @callback MyCb {$request.query.url} post
      # @callback_request_body [string] application/json desc
      # @callback_response 200 [string] application/json desc someBool:false someString:hello
      # @callback_response 400 desc someBool:false someString:hello
      # @route GET /cb_opts
    RUBY
    ir2 = Cdd::IR.new
    Cdd::Docstrings::Parser.parse(Ripper.lex(code2), ir2)
    assert ir2.openapi_spec['paths']['/cb_opts']
  end

  def test_docstrings_custom_types_and_booleans
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

    out = Cdd::Routes::Emitter.emit(ir)
    assert_includes out, '@component_response MyResp'
  end

  def test_docstrings_component_responses_without_schema
    code = <<~RUBY
      # @component_callback MyCb url post
      # @component_callback_response 200 b:false c:true

      # @component_response MyResp b:false c:true
      # @component_response ReqResp [CustomType4] application/json required:true description:test
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

    out = Cdd::Routes::Emitter.emit(ir)
    assert_match(/required:true/, out)
  end

  def test_docstrings_security_callbacks_and_external_docs_variants
    code = <<~RUBY
      # @security BearerAuth my_scope
      # @callback cb cb_url get
      # @callback_request_body [CbBody] application/json desc
      # @callback_response 200 [CbResp] application/json desc
      # @response 200 [MyResp] application/json x-custom:string_val
      # @external_docs https://example.com ext_desc
      # @op_server https://op.example.com op_desc
      # @route GET /with_details
      def some_method
      end

      # @request_body [MyBody] application/json encoding:myProp
      # @request_body_encoding myProp application/json explode:true another:stringval
      # @route POST /with_encoding
      def encoding_method
      end

      # @callback_response 200 [CbResp] application/json description:some_desc opt:stringval
      # @route POST /with_cb_desc
      def cb_desc_method
      end

      # @security
      # @callback cb cb_url get
      # @callback_request_body [CbBody] application/json
      # @callback_response 200 [CbResp] application/json
      # @response 200 [MyResp] application/json
      # @external_docs https://example.com
      # @op_server https://op.example.com
      # @route GET /without_details
      def minimal_method
      end
    RUBY

    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Docstrings::Parser.parse(tokens, ir)
    assert_equal [{ 'BearerAuth' => ['my_scope'] }], ir.openapi_spec.dig('paths', '/with_details', 'get', 'security')
    assert_equal 'https://example.com', ir.openapi_spec.dig('paths', '/with_details', 'get', 'externalDocs', 'url')
    assert_equal [{}], ir.openapi_spec.dig('paths', '/without_details', 'get', 'security')
    assert_equal 'https://example.com', ir.openapi_spec.dig('paths', '/without_details', 'get', 'externalDocs', 'url')

    code_comp = <<~RUBY
      # @component_callback_response 200 [CbResp] application/json description:some_desc opt:stringval opt2:false
      # @component_response MyResp description:some_desc opt:stringval opt2:false

      # @request_body [MyBody] application/json encoding:myProp
      # @request_body_encoding application/json myProp explode:true another:stringval My encoding desc
      # @route POST /encoding_desc
      def encoding_desc_method
      end
    RUBY
    ir_comp = Cdd::IR.new
    ir_comp.openapi_spec['components'] = { 'callbacks' => { 'cb' => { 'cb_url' => { 'get' => { 'responses' => {} } } } } }
    Cdd::Docstrings::Parser.parse(Ripper.lex(code_comp), ir_comp)
    assert_equal 'some_desc', ir_comp.openapi_spec.dig('components', 'responses', 'MyResp', 'description')
    assert_equal 'My encoding desc',
                 ir_comp.openapi_spec.dig('paths', '/encoding_desc', 'post', 'requestBody', 'content',
                                          'application/json', 'encoding', 'myProp', 'description')
  end

  def test_docstrings_descriptions_options_and_refs
    code = <<~RUBY
      # @security_scheme api_key apiKey description:Api key auth
      # @schema Item description:An item
      # @component_param filter [integer] in:query description:Filter items
      # @request_body [Item] application/json description:The body
      # @component_response MyResp [Item] application/json x-opt:true
      # @component_response EmptyResp x-opt:false
      # @response_header 200 X-Test [string] description:A test header
      # @param q [string] in:query description:The query
      # @callback myCallback {$request.query.callbackUrl} post
      # @callback_request_body [Event] application/json description:An event body
      # @route POST /cb_desc
      def dummy
      end

      # @component_header RateLimit [integer] description:Rate limit required:true
      # @component_callback MyCallback {$request.query.callbackUrl} post
      # @component_callback_response 200 [Event] application/json description:OK true_val:true
      # @component_callback_response 400 description:Bad false_val:false
      # @component_link LinkWithBody requestBody:testBody
      # @request_body [Profile] multipart/form-data
      # @request_body_encoding multipart/form-data profileImage description:A description
      # @route POST /enc_head
      def dummy2
      end

      # @component_callback SimpleCallback {$request.query.callbackUrl} post
      # @component_callback_response 200 Something
      def dummy3
      end
    RUBY
    ir = Cdd::IR.new
    Cdd::Docstrings::Parser.parse(Ripper.lex(code), ir)

    cb_op = ir.openapi_spec.dig('components', 'callbacks', 'SimpleCallback', '{$request.query.callbackUrl}', 'post')
    assert cb_op
    assert_equal 'Something', cb_op.dig('responses', '200', 'description')

    ir.openapi_spec['components']['parameters']['refParam'] = {
      'name' => 'refParam',
      'in' => 'query',
      'schema' => { '$ref' => '#/components/schemas/RefParam' }
    }
    ir.openapi_spec['components']['headers']['X-Test'] = {
      'schema' => { '$ref' => '#/components/schemas/TestSchema' }
    }
    ir.openapi_spec['paths']['/enc_head']['post']['requestBody']['content']['multipart/form-data']['encoding'] = {
      'profileImage' => {
        'headers' => {
          'X-Rate-Limit' => { '$ref' => '#/components/headers/RateLimit' }
        }
      }
    }
    ir.openapi_spec['paths']['/ref'] = {
      'get' => {
        'responses' => {
          '200' => {
            'description' => 'OK',
            'headers' => {
              'X-Ref' => {
                'schema' => { '$ref' => '#/components/schemas/RefHeader' }
              }
            },
            'links' => {
              'MyLink' => {
                'requestBody' => '$request.body#/id'
              }
            }
          }
        }
      }
    }

    out = Cdd::Routes::Emitter.emit(ir)
    assert_match(/@component_param refParam \[RefParam\]/, out)
    assert_match(/@response_header 200 X-Ref \[RefHeader\]/, out)
    assert_match(%r{@link 200 MyLink requestBody:\$request.body#/id}, out)
  end
end
