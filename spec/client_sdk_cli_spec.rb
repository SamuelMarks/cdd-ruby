# frozen_string_literal: true

require_relative 'spec_helper'
require 'tempfile'

class ClientSdkCliTest < Minitest::Test
  def test_client_sdk_cli_emit_full_metadata
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
    assert_includes out, '# Auto-generated SDK CLI for Title'
    assert_includes out, "when 'op'"
    file.unlink
  end

  def test_client_sdk_cli_emit_minimal_metadata
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
    assert_includes out, "when 'post__p'"
    file.unlink
  end

  def test_client_sdk_cli_emit_operation_docs_and_responses
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
    assert_includes out, '# External Docs: http://ext'
    assert_includes out, '# Tags: a, b'
    file.unlink

    openapi2 = {
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
    file2 = Tempfile.new(['openapi', '.json'])
    file2.write(openapi2.to_json)
    file2.close
    out2 = Cdd::ClientSdkCli::Emitter.emit_sdk_cli(input: file2.path)
    assert_includes out2, '# Accepts text/plain'
    assert_includes out2, '# Expects 200: OK'
    file2.unlink
  end

  def test_client_sdk_cli_emit_optional_components_and_discriminators
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
        },
        '/p2' => {
          'get' => {
            'tags' => nil,
            'externalDocs' => nil,
            'requestBody' => { 'content' => nil }
          },
          'post' => {
            'tags' => false,
            'externalDocs' => false,
            'requestBody' => { 'content' => nil }
          }
        }
      }
    }
    file = Tempfile.new(['openapi', '.json'])
    file.write(openapi.to_json)
    file.close
    out = Cdd::ClientSdkCli::Emitter.emit_sdk_cli(input: file.path)
    assert_includes out, 'var v default=d enum='
    assert_includes out, 'oauth (oauth2)'
    assert_includes out, 'Schemas Available:'
    assert_includes out, 'Discriminator: p'
    assert_includes out, "when 'get__p2'"
    assert_includes out, "when 'post__p2'"
    file.unlink

    openapi_no_schemas = {
      'openapi' => '3.0.0',
      'components' => {
        'securitySchemes' => { 'apiKey' => { 'type' => 'apiKey' } }
      }
    }
    file_no_schemas = Tempfile.new(['openapi', '.json'])
    file_no_schemas.write(openapi_no_schemas.to_json)
    file_no_schemas.close
    out_no_schemas = Cdd::ClientSdkCli::Emitter.emit_sdk_cli(input: file_no_schemas.path)
    assert_includes out_no_schemas, 'Security Required:'
    refute_includes out_no_schemas, 'Schemas Available:'
    file_no_schemas.unlink
  end

  def test_client_sdk_cli_parse_mcp_command
    ir = Cdd::IR.new
    ir.openapi_spec = {}
    tokens = Ripper.lex("when 'mcp'\n")
    Cdd::ClientSdkCli::Parser.parse(tokens, ir)
    assert_nil ir.openapi_spec['paths']
  end
end
