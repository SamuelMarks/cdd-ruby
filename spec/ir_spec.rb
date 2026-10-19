# frozen_string_literal: true

require_relative 'spec_helper'

class IrTest < Minitest::Test
  def test_ir_to_h_and_typed_models
    spec = {
      'openapi' => '3.2.0',
      'info' => {
        'title' => 'Petstore',
        'version' => '1.2.3',
        'summary' => 'Petstore summary',
        'description' => 'Petstore description',
        'termsOfService' => 'https://example.com/tos',
        'contact' => { 'name' => 'Support' },
        'license' => { 'name' => 'MIT' }
      },
      'servers' => [
        {
          'url' => 'https://{env}.example.com',
          'description' => 'Main server',
          'variables' => {
            'env' => { 'default' => 'prod', 'enum' => %w[prod staging], 'description' => 'Environment' }
          }
        },
        {
          'url' => 'https://fallback.example.com'
        }
      ],
      'components' => {
        'schemas' => {
          'Pet' => {
            'type' => 'object',
            'description' => 'A pet',
            'required' => ['id'],
            'properties' => {
              'id' => { 'type' => 'integer', 'description' => 'ID', 'example' => 1 },
              'owner' => { '$ref' => '#/components/schemas/User' }
            }
          },
          'EmptySchema' => {}
        }
      }
    }

    ir = Cdd::IR.from_openapi_hash(spec)
    assert_equal %w[Pet EmptySchema], ir.classes
    assert_equal spec, ir.to_openapi_hash

    info = ir.typed_info
    assert_equal 'Petstore', info.title
    assert_equal '1.2.3', info.version
    assert_equal 'Petstore summary', info.summary

    default_ir = Cdd::IR.from_openapi_hash({ 'components' => 'invalid' })
    default_info = default_ir.typed_info
    assert_equal 'Generated API', default_info.title
    assert_equal '0.0.4', default_info.version
    assert_empty default_ir.typed_servers
    assert_empty default_ir.typed_schemas

    no_schemas_ir = Cdd::IR.from_openapi_hash({ 'components' => {} })
    assert_empty no_schemas_ir.classes
    assert_empty no_schemas_ir.typed_schemas

    servers = ir.typed_servers
    assert_equal 2, servers.size
    assert_equal 'https://{env}.example.com', servers[0].url
    assert_equal 'prod', servers[0].variables['env'].default
    assert_empty servers[1].variables

    schemas = ir.typed_schemas
    assert_equal 2, schemas.size
    pet_schema = schemas.find { |s| s.name == 'Pet' }
    assert_equal 'object', pet_schema.type
    assert_equal ['id'], pet_schema.required
    assert_equal 2, pet_schema.properties.size
    assert_equal '#/components/schemas/User', pet_schema.properties[1].ref

    empty_schema = schemas.find { |s| s.name == 'EmptySchema' }
    assert_empty empty_schema.properties
    assert_empty empty_schema.required

    hash = Cdd::IR.new.to_h
    assert_equal %w[classes routes openapi tests mocks arazzo workflows].sort, hash.keys.sort
    assert_equal '3.2.0', hash['openapi']['openapi']

    rpc_err = Cdd::RpcError.new('Bad method', code: -32_601)
    assert_equal 'Bad method', rpc_err.message
    assert_equal(-32_601, rpc_err.code)

    cfg = Cdd::Config.new(subcommand: 'to_sdk', input: 'spec.json')
    assert_equal 'to_sdk', cfg[:subcommand]
    assert_equal 'spec.json', cfg['input']
    assert_nil cfg[:unknown_key]
    assert_equal({ subcommand: 'to_sdk', input: 'spec.json' }, cfg.to_h)
  end

  def test_typed_paths_security_schemes_examples_and_errors
    spec = {
      'openapi' => '3.2.0',
      'paths' => {
        '/pets/{petId}' => {
          'summary' => 'Pet endpoint',
          'parameters' => [{ 'name' => 'petId', 'in' => 'path', 'required' => true, 'schema' => { 'type' => 'string' } }],
          'get' => {
            'operationId' => 'getPet',
            'responses' => { '200' => { 'description' => 'Found' } }
          },
          'post' => {
            'operationId' => 'updatePet',
            'summary' => 'Update pet',
            'tags' => ['pets'],
            'parameters' => [{ 'name' => 'q', 'in' => 'query' }],
            'requestBody' => {
              'description' => 'Pet payload',
              'required' => true,
              'content' => {
                'multipart/form-data' => {
                  'schema' => { '$ref' => '#/components/schemas/Pet' },
                  'encoding' => { 'avatar' => { 'contentType' => 'image/png', 'explode' => true } }
                }
              }
            },
            'responses' => {
              '200' => {
                'description' => 'Updated',
                'headers' => { 'X-Rate' => { 'description' => 'Limit', 'schema' => { 'type' => 'integer' } } },
                'content' => { 'application/json' => { 'schema' => { '$ref' => '#/components/schemas/Pet' } } },
                'links' => { 'GetPet' => { 'operationId' => 'getPet', 'description' => 'Fetch pet' } }
              }
            }
          }
        }
      },
      'components' => {
        'securitySchemes' => {
          'oauth' => {
            'type' => 'oauth2',
            'flows' => { 'implicit' => { 'authorizationUrl' => 'https://auth', 'scopes' => {} } }
          },
          'api_key' => { 'type' => 'apiKey', 'name' => 'X-Key', 'in' => 'header' }
        },
        'examples' => {
          'samplePet' => { 'summary' => 'Example for Pet', 'value' => { 'id' => 1 } },
          'rawEx' => { 'value' => 'plain' }
        }
      }
    }

    ir = Cdd::IR.from_openapi_hash(spec)
    assert_equal ['GET /pets/{petId}', 'POST /pets/{petId}'], ir.routes
    assert_equal %w[samplePet rawEx], ir.mocks

    paths = ir.typed_paths
    assert_equal 1, paths.size
    assert_equal '/pets/{petId}', paths[0].path
    assert_equal 1, paths[0].parameters.size
    assert_nil paths[0].operations['get'].request_body
    post_op = paths[0].operations['post']
    assert_equal 'updatePet', post_op.operation_id
    assert_equal 'image/png', post_op.request_body.content['multipart/form-data'].encoding['avatar'].content_type
    assert_equal 'Limit', post_op.responses['200'].headers['X-Rate'].description
    assert_equal 'getPet', post_op.responses['200'].links['GetPet'].operation_id

    schemes = ir.typed_security_schemes
    assert_equal 2, schemes.size
    assert_equal 'https://auth', schemes[0].flows.implicit['authorizationUrl']
    assert_nil schemes[1].flows

    examples = ir.typed_examples
    assert_equal 2, examples.size
    assert_equal 'Pet', examples[0].schema_ref
    assert_nil examples[1].schema_ref

    empty_ir = Cdd::IR.new
    assert_empty empty_ir.typed_security_schemes
    assert_empty empty_ir.typed_examples

    assert_equal '1', Cdd::TokenScanner.sample_param_value({ 'schema' => { 'type' => 'integer' } })
    assert_includes Cdd::TokenScanner.sample_param_value(
      { 'in' => 'body', 'name' => 'body', 'schema' => { '$ref' => '#/Order' } }
    ), 'petId'
    assert_includes Cdd::TokenScanner.sample_param_value(
      { 'in' => 'body', 'name' => 'body', 'schema' => { 'type' => 'array' } }
    ), 'user1'
    assert_includes Cdd::TokenScanner.sample_param_value(
      { 'in' => 'body', 'name' => 'body', 'schema' => { '$ref' => '#/User' } }
    ), 'user1'
    assert_includes Cdd::TokenScanner.sample_param_value(
      { 'in' => 'body', 'name' => 'body', 'schema' => { '$ref' => '#/Pet' } }
    ), 'doggie'
    assert_equal "'available'", Cdd::TokenScanner.sample_param_value({ 'in' => 'query', 'name' => 'status' })
    assert_equal "'test_tag'", Cdd::TokenScanner.sample_param_value({ 'in' => 'query', 'name' => 'tag' })

    assert_raises(Cdd::EmitError) { Cdd::Emitter.validate_spec_hash([1, 2, 3]) }
    assert_raises(Cdd::ParseError) { Cdd::Arazzo::Parser.parse_json_tag('{bad') }

    require 'tempfile'
    bad_file = Tempfile.new(['bad', '.json'])
    bad_file.write('{not valid json')
    bad_file.close
    assert_raises(Cdd::ParseError) { Cdd::Emitter.parse_spec_file(bad_file.path) }
    bad_file.unlink

    sdk_ir = Cdd::IR.new
    sdk_code = "class << self\nend\nclass ClientSdk\ndef ( ) # a\nend\ndef no_str\nreq_path = 123\nend\ndef foo\nreq_path = '/custom'\nend\ndef bar\nend\nend\n"
    Cdd::ClientSdk::Parser.parse(Ripper.lex(sdk_code), sdk_ir)
    assert_equal 'foo', sdk_ir.openapi_spec.dig('paths', '/custom', 'get', 'operationId')

    rbs_path = File.expand_path('../sig/cdd.rbs', __dir__)
    refute_includes File.read(rbs_path), 'untyped'
  end
end
