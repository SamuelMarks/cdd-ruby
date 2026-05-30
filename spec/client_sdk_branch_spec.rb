# frozen_string_literal: true

require_relative 'spec_helper'
require 'tempfile'

class ClientSdkBranchTest < Minitest::Test
  def test_client_sdk_emit_oauth
    openapi = {
      'openapi' => '3.0.0',
      'components' => {
        'securitySchemes' => {
          'oauth' => { 'type' => 'oauth2' },
          'apikey' => { 'type' => 'apiKey' }
        }
      }
    }
    file = Tempfile.new(['openapi', '.json'])
    file.write(openapi.to_json)
    file.close
    out = Cdd::ClientSdk::Emitter.emit_sdk(input: file.path)
    assert_match(/authorize_oauth2/, out)
    file.unlink
  end

  def test_client_sdk_emit_missing_request_body
    openapi = {
      'openapi' => '3.0.0',
      'info' => { 'title' => 'Title' },
      'components' => {
        'schemas' => {
          'A' => { 'properties' => { 'p' => {} } }
        }
      },
      'paths' => {
        '/test' => {
          'get' => {
            'requestBody' => {
              'content' => {
                'application/json' => {
                  'encoding' => {
                    'a' => { 'contentType' => 'text/plain', 'headers' => { 'b' => 'c' }, 'style' => 'simple', 'explode' => true, 'allowReserved' => false }
                  }
                }
              }
            },
            'responses' => {
              '200' => { 'content' => { 'application/json' => {} } }
            },
            'callbacks' => {
              'cb' => { 'http://cb' => { 'post' => { 'requestBody' => { 'content' => { 'a' => {} } } } } }
            }
          }
        }
      }
    }
    file = Tempfile.new(['openapi', '.json'])
    file.write(openapi.to_json)
    file.close
    out = Cdd::ClientSdk::Emitter.emit_sdk(input: file.path)
    refute_nil out
    file.unlink
  end
end
