# frozen_string_literal: true

require_relative 'spec_helper'
require 'tempfile'

class ServerBranchTest < Minitest::Test
  def test_server_emit_branches
    openapi = {
      'openapi' => '3.0.0',
      'info' => {
        'title' => 'Title',
        'version' => '1.0',
        'description' => 'Desc'
      },
      'servers' => [
        {
          'url' => 'http://test',
          'description' => 'Test Server',
          'variables' => {
            'var1' => { 'default' => 'a', 'enum' => %w[a b] }
          }
        }
      ],
      'components' => {
        'securitySchemes' => {
          'ApiAuth' => { 'type' => 'apiKey' }
        },
        'schemas' => {
          'MyObj' => {
            'type' => 'object',
            'properties' => { 'p1' => { 'type' => 'string' } },
            'discriminator' => {
              'propertyName' => 'type',
              'mapping' => { 'a' => 'A' }
            },
            'xml' => { 'name' => 'obj' }
          }
        }
      },
      'paths' => {
        '/test/{id}' => {
          'get' => {
            'operationId' => 'myOp',
            'summary' => 'sum',
            'description' => 'desc',
            'deprecated' => true,
            'parameters' => [
              { 'name' => 'p1', 'in' => 'path', 'required' => true, 'schema' => { 'type' => 'integer' } }
            ],
            'requestBody' => {
              'content' => {
                'application/json' => {
                  'schema' => { 'type' => 'string' }
                }
              }
            }
          }
        }
      }
    }

    file = Tempfile.new(['openapi', '.json'])
    file.write(openapi.to_json)
    file.close

    out_dir = 'test_server_emit_out'
    Cdd::ServerGen::Emitter.emit_server(input: file.path, output: out_dir)

    models_out = File.read(File.join(out_dir, 'models', 'myobj.rb'))
    mcp_out = File.read(File.join(out_dir, 'routes', 'mcp_routes.rb'))

    assert_match(/Discriminator/, models_out)
    assert_match(%r{roots/list}, mcp_out)
    assert_match(%r{resources/templates/list}, mcp_out)
    assert_match(%r{sampling/createMessage}, mcp_out)

    FileUtils.rm_rf(out_dir)
    file.unlink
  end
end
