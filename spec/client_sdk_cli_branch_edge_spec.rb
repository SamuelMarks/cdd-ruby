# frozen_string_literal: true

require_relative 'spec_helper'
require 'tempfile'

class ClientSdkCliBranchEdgeTest < Minitest::Test
  def test_edges
    openapi = {
      'openapi' => '3.0.0',
      'servers' => [
        { 'url' => 'http://test', 'variables' => nil },
        { 'url' => 'http://test2', 'variables' => { 'v' => { 'default' => 'd', 'enum' => nil } } }
      ],
      'components' => {
        'securitySchemes' => {
          'oauth' => { 'type' => 'oauth2', 'flows' => { 'implicit' => { 'scopes' => nil } } },
          'oauth2' => { 'type' => 'oauth2', 'flows' => { 'implicit' => nil } }
        },
        'schemas' => {
          'S1' => { 'discriminator' => false },
          'S2' => { 'discriminator' => { 'propertyName' => 'p', 'mapping' => false } },
          'S3' => { 'discriminator' => { 'propertyName' => 'p', 'mapping' => nil } }
        }
      },
      'paths' => {
        '/p' => {
          'get' => {
            'requestBody' => {
              'content' => {
                'text' => {
                  'examples' => false,
                  'encoding' => false
                },
                'json' => {
                  'examples' => nil,
                  'encoding' => nil
                }
              }
            },
            'responses' => {
              '200' => {
                'headers' => false,
                'links' => false
              },
              '400' => {
                'headers' => nil,
                'links' => nil
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

class ClientSdkCliBranchEdgeTest2 < Minitest::Test
  def test_edges2
    openapi = {
      'openapi' => '3.0.0',
      'paths' => {
        '/p2' => {
          'get' => {
            'tags' => nil,
            'externalDocs' => nil,
            'requestBody' => {
              'content' => nil
            }
          },
          'post' => {
            'tags' => false,
            'externalDocs' => false,
            'requestBody' => {
              'content' => nil
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
