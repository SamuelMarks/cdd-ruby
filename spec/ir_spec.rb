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
end
