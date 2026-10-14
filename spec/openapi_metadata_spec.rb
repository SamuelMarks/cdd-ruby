# frozen_string_literal: true

require_relative 'spec_helper'

class OpenapiMetadataTest < Minitest::Test
  def test_openapi_metadata
    code = <<~RUBY
      # @api_title My API
      # @api_version 1.2.3
      # @api_description The coolest API
      # @api_self https://example.com/openapi.json
      # @api_jsonSchemaDialect https://json-schema.org/draft/2020-12/schema
      # @api_server https://example.com/api Production server
      # @api_server https://staging.example.com/api Staging server
      # @api_server https://test.example.com/api
      # @api_tag User User operations
      # @api_tag Admin Admin operations
      # @api_tag System
      # @api_externalDocs https://docs.example.com Full documentation
      # @api_webhook newPet POST
    RUBY

    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Openapi::Parser.parse(tokens, ir)

    assert_equal 'My API', ir.openapi_spec['info']['title']
    assert_equal '1.2.3', ir.openapi_spec['info']['version']
    assert_equal 'The coolest API', ir.openapi_spec['info']['description']
    assert_equal 'https://example.com/openapi.json', ir.openapi_spec['$self']
    assert_equal 'https://json-schema.org/draft/2020-12/schema', ir.openapi_spec['jsonSchemaDialect']

    servers = ir.openapi_spec['servers']
    assert_equal 3, servers.length
    assert_equal 'https://example.com/api', servers[0]['url']
    assert_equal 'Production server', servers[0]['description']
    assert_equal 'https://test.example.com/api', servers[2]['url']
    assert_nil servers[2]['description']

    tags = ir.openapi_spec['tags']
    assert_equal 3, tags.length
    assert_equal 'User', tags[0]['name']
    assert_equal 'User operations', tags[0]['description']
    assert_equal 'System', tags[2]['name']
    assert_nil tags[2]['description']

    ed = ir.openapi_spec['externalDocs']
    assert_equal 'https://docs.example.com', ed['url']
    assert_equal 'Full documentation', ed['description']

    wh = ir.openapi_spec['webhooks']['newPet']['post']
    assert_equal 'OK', wh['responses']['200']['description']

    emitted = Cdd::Openapi::Emitter.emit(ir)
    assert_match(/# @api_title My API/, emitted)
    assert_match(/# @api_version 1.2.3/, emitted)
    assert_match(/# @api_description The coolest API/, emitted)
    assert_match(%r{# @api_self https://example.com/openapi.json}, emitted)
    assert_match(%r{# @api_jsonSchemaDialect https://json-schema.org/draft/2020-12/schema}, emitted)
    assert_match(%r{# @api_server https://example.com/api Production server}, emitted)
    assert_match(/# @api_tag User User operations/, emitted)
    assert_match(%r{# @api_externalDocs https://docs.example.com Full documentation}, emitted)
    assert_match(/# @api_webhook newPet POST/, emitted)
  end

  def test_openapi_external_docs_no_desc
    code = <<~RUBY
      # @api_externalDocs https://foo.com
    RUBY
    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Openapi::Parser.parse(tokens, ir)
    assert_nil ir.openapi_spec['externalDocs']['description']
  end

  def test_swagger_metadata
    code = <<~RUBY
      # @api_title My Swagger API
      # @api_version 1.0.0
      # @swagger_version 2.0
    RUBY

    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Openapi::Parser.parse(tokens, ir)

    assert_equal 'My Swagger API', ir.openapi_spec['info']['title']
    assert_equal '2.0', ir.openapi_spec['swagger']
    assert_nil ir.openapi_spec['openapi']

    emitted = Cdd::Openapi::Emitter.emit(ir)
    assert_match(/# @swagger_version 2.0/, emitted)
  end

  def test_openapi_emit_optional_fields
    ir = Cdd::IR.new
    ir.openapi_spec['info'] = {
      'title' => 'T', 'version' => '1', 'description' => 'D'
    }
    ir.openapi_spec['swagger'] = '2.0'
    ir.openapi_spec['$self'] = 'self'
    ir.openapi_spec['jsonSchemaDialect'] = 'http://json-schema.org/draft-04/schema#'
    ir.openapi_spec['servers'] = [{ 'url' => 'http://test' }]
    ir.openapi_spec['tags'] = [{ 'name' => 't1' }]

    out = Cdd::Openapi::Emitter.emit(ir)
    assert_match(%r{@api_server http://test$}, out)
    assert_match(/@api_tag t1$/, out)

    ir2 = Cdd::IR.new
    ir2.openapi_spec['externalDocs'] = { 'url' => 'http://ext' }
    assert_match(%r{@api_externalDocs http://ext$}, Cdd::Openapi::Emitter.emit(ir2))

    ir3 = Cdd::IR.new
    ir3.openapi_spec['webhooks'] = { 'my_hook' => { 'post' => {} } }
    assert_match(/@api_webhook my_hook POST/, Cdd::Openapi::Emitter.emit(ir3))

    ir4 = Cdd::IR.new
    ir4.openapi_spec['externalDocs'] = { 'url' => 'http://ext', 'description' => 'Docs' }
    assert_match(%r{@api_externalDocs http://ext Docs$}, Cdd::Openapi::Emitter.emit(ir4))
  end
end
