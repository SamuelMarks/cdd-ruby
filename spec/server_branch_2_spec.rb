# frozen_string_literal: true

require_relative 'spec_helper'
require 'tempfile'

class ServerBranchTest2 < Minitest::Test
  def test_server_emit_branches2
    openapi = {
      'openapi' => '3.0.0',
      'info' => {},
      'servers' => [
        { 'url' => 'http://test', 'variables' => nil },
        { 'url' => 'http://test2', 'variables' => { 'v' => { 'default' => 'd', 'enum' => nil } } }
      ],
      'components' => {
        'securitySchemes' => false,
        'schemas' => {
          'S1' => {
            'xml' => { 'name' => 's' },
            'discriminator' => false
          },
          'S2' => {
            'properties' => { 'p' => { 'type' => 'string' } },
            'discriminator' => {
              'propertyName' => 'p',
              'mapping' => nil
            }
          }
        }
      },
      'paths' => {
        '/p' => {
          'get' => {
            'parameters' => [
              { 'name' => 'p1', 'in' => 'query', 'required' => false }
            ],
            'requestBody' => {
              'content' => {
                'text/plain' => {}
              }
            }
          },
          'post' => {
            'requestBody' => {}
          }
        }
      }
    }

    file = Tempfile.new(['openapi', '.json'])
    file.write(openapi.to_json)
    file.close

    out = Cdd::ServerGen::Emitter.emit_server(input: file.path)
    refute_nil out
    file.unlink
  end
end
