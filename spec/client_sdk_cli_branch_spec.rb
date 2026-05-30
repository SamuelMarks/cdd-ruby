# frozen_string_literal: true

require_relative 'spec_helper'
require 'tempfile'

class ClientSdkCliBranchTest < Minitest::Test
  def test_client_sdk_cli_emit
    openapi = {
      'openapi' => '3.0.0',
      'info' => {
        'title' => 'Title',
        'version' => '1.0',
        'summary' => 'S',
        'contact' => { 'name' => 'Me' },
        'license' => { 'url' => 'http://lic' }
      },
      'servers' => [
        {
          'url' => 'http://test',
          'description' => 'Test',
          'variables' => {
            'v1' => { 'default' => 'd', 'enum' => ['a'] }
          }
        }
      ],
      'components' => {
        'securitySchemes' => {
          'oauth' => { 'type' => 'oauth2', 'flows' => { 'implicit' => { 'scopes' => { 'a' => 'b' } } } },
          'apiKey' => { 'type' => 'apiKey' }
        },
        'schemas' => {
          'S' => {
            'discriminator' => {
              'propertyName' => 'p',
              'mapping' => { 'a' => 'A' }
            }
          }
        }
      },
      'paths' => {
        '/p' => {
          'get' => {
            'operationId' => 'op',
            'summary' => 'sum',
            'parameters' => [
              { 'name' => 'p1', 'in' => 'query', 'required' => true },
              { 'name' => 'p2', 'in' => 'query' }
            ],
            'requestBody' => {
              'content' => { 'application/json' => { 'schema' => { 'type' => 'string' } } }
            }
          }
        }
      }
    }
    file = Tempfile.new(['openapi', '.json'])
    file.write(openapi.to_json)
    file.close

    out = Cdd::ClientSdkCli::Emitter.emit_sdk_cli(input: file.path)
    refute_nil out
    file.unlink
  end

  def test_client_sdk_cli_emit2
    openapi = {
      'openapi' => '3.0.0',
      'info' => {},
      'components' => {
        'securitySchemes' => false,
        'schemas' => {
          'S' => {
            'discriminator' => false
          }
        }
      },
      'paths' => {
        '/p' => {
          'post' => {}
        }
      }
    }
    file = Tempfile.new(['openapi', '.json'])
    file.write(openapi.to_json)
    file.close

    out = Cdd::ClientSdkCli::Emitter.emit_sdk_cli(input: file.path)
    refute_nil out
    file.unlink
  end
end

class ClientSdkCliBranchTest2 < Minitest::Test
  def test_client_sdk_cli_emit3
    openapi = {
      'openapi' => '3.0.0',
      'paths' => {
        '/p' => {
          'get' => {
            'externalDocs' => { 'url' => 'http://ext' },
            'tags' => %w[a b],
            'requestBody' => {
              'required' => true,
              'content' => {
                'text/plain' => {
                  'examples' => { 'ex' => 'val' },
                  'encoding' => { 'a' => 'b' }
                }
              }
            },
            'responses' => {
              '200' => {
                'description' => 'OK',
                'headers' => { 'H' => 'V' },
                'content' => { 'application/json' => {} },
                'links' => { 'L' => 'V' }
              }
            }
          }
        }
      }
    }
    file = Tempfile.new(['openapi', '.json'])
    file.write(openapi.to_json)
    file.close
    out = Cdd::ClientSdkCli::Emitter.emit_sdk_cli(input: file.path)
    refute_nil out
    file.unlink
  end
end

class ClientSdkCliBranchTest3 < Minitest::Test
  def test_client_sdk_cli_emit4
    openapi = {
      'openapi' => '3.0.0',
      'paths' => {
        '/p' => {
          'get' => {
            'externalDocs' => false,
            'tags' => false,
            'requestBody' => {
              'content' => {
                'text/plain' => {
                  'examples' => false,
                  'encoding' => false
                }
              }
            },
            'responses' => {
              '200' => {
                'description' => 'OK',
                'headers' => false,
                'links' => false
              }
            }
          }
        }
      }
    }
    file = Tempfile.new(['openapi', '.json'])
    file.write(openapi.to_json)
    file.close
    out = Cdd::ClientSdkCli::Emitter.emit_sdk_cli(input: file.path)
    refute_nil out
    file.unlink
  end
end
