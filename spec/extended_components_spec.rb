# frozen_string_literal: true

require_relative 'spec_helper'

class ExtendedComponentsTest < Minitest::Test
  def test_component_request_body
    code = <<~RUBY
      # @component_request_body UserBody [User] application/json required:true description:The user body
      # @request_body_ref UserBody
      # @route POST /users
      def post_users
      end
    RUBY
    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Docstrings::Parser.parse(tokens, ir)

    rb = ir.openapi_spec['components']['requestBodies']['UserBody']
    assert_equal '#/components/schemas/User', rb['content']['application/json']['schema']['$ref']
    assert_equal true, rb['required']
    assert_equal 'The user body', rb['description']

    op = ir.openapi_spec['paths']['/users']['post']
    assert_equal '#/components/requestBodies/UserBody', op['requestBody']['$ref']

    out = Cdd::Routes::Emitter.emit(ir)
    assert_match(%r{@component_request_body UserBody \[User\] application/json required:true description:The user body},
                 out)
    assert_match(/@request_body_ref UserBody/, out)
  end

  def test_component_header
    code = <<~RUBY
      # @component_header RateLimit [integer] description:Rate limit
      # @response 200 OK
      # @response_header_ref 200 X-Rate-Limit RateLimit
      # @route GET /limits
      def get_limits
      end
    RUBY
    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Docstrings::Parser.parse(tokens, ir)

    h = ir.openapi_spec['components']['headers']['RateLimit']
    assert_equal 'integer', h['schema']['type']
    assert_equal 'Rate limit', h['description']

    op = ir.openapi_spec['paths']['/limits']['get']
    assert_equal '#/components/headers/RateLimit', op['responses']['200']['headers']['X-Rate-Limit']['$ref']

    out = Cdd::Routes::Emitter.emit(ir)
    assert_match(/@component_header RateLimit \[integer\] description:Rate limit/, out)
    assert_match(/@response_header_ref 200 X-Rate-Limit RateLimit/, out)
  end

  def test_component_link
    code = <<~RUBY
      # @component_link GetUser operationId:getUser parameters.id:$response.body#/id description:Link to user
      # @response 200 OK
      # @link_ref 200 GetUserLink GetUser
      # @route GET /linked
      def get_linked
      end
    RUBY
    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Docstrings::Parser.parse(tokens, ir)

    l = ir.openapi_spec['components']['links']['GetUser']
    assert_equal 'getUser', l['operationId']
    assert_equal '$response.body#/id', l['parameters']['id']
    assert_equal 'Link to user', l['description']

    op = ir.openapi_spec['paths']['/linked']['get']
    assert_equal '#/components/links/GetUser', op['responses']['200']['links']['GetUserLink']['$ref']

    out = Cdd::Routes::Emitter.emit(ir)
    assert_match(
      %r{@component_link GetUser operationId:getUser parameters\.id:\$response\.body#/id description:Link to user}, out
    )
    assert_match(/@link_ref 200 GetUserLink GetUser/, out)
  end

  def test_component_media_types_collection_formats_and_additional_operations
    code = <<~RUBY
      # @component_media_type EventStream [Event] itemSchema:Event itemEncoding.contentType:application/json prefixEncoding.contentType:text/plain
      # @component_param TagsParam [array] in:query collectionFormat:multi items.type:string items.collectionFormat:csv Tag filter
      # @component_header X-Tags [array] required:true collectionFormat:pipes items.type:string items.collectionFormat:ssv description:Tag header

      # @summary Purge event
      # @produces application/json, application/xml
      # @param tags [array] in:query collectionFormat:csv items.type:string items.collectionFormat:pipes
      # @request_body [Event] application/jsonl required:true itemSchema:Event itemEncoding.contentType:application/json prefixEncoding.contentType:text/plain Stream body
      # @request_body_encoding application/jsonl payload contentType:application/json itemEncoding.contentType:text/plain prefixEncoding.contentType:application/octet-stream
      # @response 200 [Event] application/jsonl itemSchema:Event itemEncoding.contentType:application/json prefixEncoding.contentType:text/plain OK
      # @response_header 200 X-Rate [array] collectionFormat:tsv items.type:integer
      # @additional_route PURGE /events/{id}
      purge '/events/:id' do
      end

      # @additional_route COPY /events/{id}
      copy '/events/:id' do
      end
    RUBY

    tokens = Ripper.lex(code)
    ir = Cdd::IR.new
    Cdd::Docstrings::Parser.parse(tokens, ir)

    mt_comp = ir.openapi_spec.dig('components', 'mediaTypes', 'EventStream')
    assert_equal({ '$ref' => '#/components/schemas/Event' }, mt_comp['schema'])
    assert_equal({ '$ref' => '#/components/schemas/Event' }, mt_comp['itemSchema'])
    assert_equal({ 'contentType' => 'application/json' }, mt_comp['itemEncoding'])
    assert_equal([{ 'contentType' => 'text/plain' }], mt_comp['prefixEncoding'])

    p_comp = ir.openapi_spec.dig('components', 'parameters', 'TagsParam')
    assert_equal 'multi', p_comp['collectionFormat']
    assert_equal 'csv', p_comp.dig('items', 'collectionFormat')

    h_comp = ir.openapi_spec.dig('components', 'headers', 'X-Tags')
    assert_equal 'pipes', h_comp['collectionFormat']
    assert_equal 'ssv', h_comp.dig('items', 'collectionFormat')

    purge_op = ir.openapi_spec.dig('paths', '/events/{id}', 'additionalOperations', 'PURGE')
    assert_equal %w[application/json application/xml], purge_op['produces']
    tags_param = purge_op['parameters'].find { |p| p['name'] == 'tags' }
    assert_equal 'csv', tags_param['collectionFormat']
    assert_equal 'pipes', tags_param.dig('items', 'collectionFormat')

    typed_path = ir.typed_paths.first
    assert_includes typed_path.additional_operations.keys, 'PURGE'
    typed_op = typed_path.additional_operations['PURGE']
    assert_equal %w[application/json application/xml], typed_op.produces
    typed_mt = typed_op.request_body.content['application/jsonl']
    assert_equal({ '$ref' => '#/components/schemas/Event' }, typed_mt.item_schema)
    assert_equal 'application/json', typed_mt.item_encoding.content_type
    assert_equal 'text/plain', typed_mt.prefix_encoding.first.content_type
    typed_enc = typed_mt.encoding['payload']
    assert_equal 'text/plain', typed_enc.item_encoding.content_type
    assert_equal 'application/octet-stream', typed_enc.prefix_encoding.first.content_type

    out = Cdd::Routes::Emitter.emit(ir)
    assert_includes out, '# @component_media_type EventStream [Event] itemSchema:Event ' \
                         'itemEncoding.contentType:application/json prefixEncoding.contentType:text/plain'
    assert_includes out, 'collectionFormat:multi items.type:string items.collectionFormat:csv'
    assert_includes out, '# @produces application/json, application/xml'
    assert_includes out, '# @additional_route PURGE /events/{id}'

    doc_out = Cdd::Docstrings::Emitter.emit(ir)
    assert_includes doc_out, '# @additional_route PURGE /events/{id}'

    fn_out = Cdd::Functions::Emitter.emit(ir)
    assert_includes fn_out, '# @api_client PURGE /events/{id}'

    from_hash_ir = Cdd::IR.from_openapi_hash(ir.openapi_spec)
    assert_includes from_hash_ir.routes, 'PURGE /events/{id}'
  end
end
