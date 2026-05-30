# frozen_string_literal: true

require_relative 'spec_helper'

class RoutesBranchTest < Minitest::Test
  def test_routes_parse_branches
    code = <<~RUBY
      # No string literal follows method
      get 123

      # Beg token but no content
      get ""
    RUBY
    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Routes::Parser.parse(tokens, ir)
  end

  def test_routes_emit_components
    ir = Cdd::IR.new
    ir.openapi_spec['components'] = {
      'parameters' => {
        'MyP' => {
          'in' => 'query',
          'schema' => { 'type' => 'integer' },
          'required' => true,
          'style' => 'simple',
          'explode' => true,
          'allowReserved' => true,
          'allowEmptyValue' => false,
          'deprecated' => true,
          'description' => 'hello'
        },
        'MyP2' => {
          'in' => 'query'
        }
      },
      'requestBodies' => {
        'Rb1' => {
          'content' => {
            'application/json' => {
              'schema' => { 'type' => 'string' }
            }
          },
          'required' => false
        },
        'Rb2' => {
          'content' => {
            'application/json' => {
              'schema' => { 'type' => 'string' }
            }
          },
          'description' => 'yes'
        }
      },
      'responses' => {
        'R1' => {
          'description' => 'desc',
          'content' => {
            'application/json' => {
              'schema' => { 'type' => 'string' }
            }
          }
        }
      },
      'headers' => {
        'H1' => {
          'schema' => { 'type' => 'string' },
          'required' => true,
          'description' => 'desc'
        }
      },
      'links' => {
        'L1' => {
          'operationId' => 'op'
        }
      },
      'callbacks' => {
        'Cb1' => {
          'http://cb' => {
            'post' => {
              'requestBody' => {
                'content' => {
                  'application/json' => {
                    'schema' => { '$ref' => '#/components/schemas/A' }
                  }
                }
              },
              'responses' => {
                '200' => {
                  'description' => 'ok',
                  'content' => {
                    'application/json' => {
                      'schema' => { '$ref' => '#/components/schemas/A' }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }

    out = Cdd::Routes::Emitter.emit(ir)
    assert_match(/@component_param/, out)
  end

  def test_routes_emit_servers
    ir = Cdd::IR.new
    ir.openapi_spec['paths'] = {
      '/test2' => {
        'get' => {
          'operationId' => 'op2',
          'externalDocs' => {
            'url' => 'http://ext',
            'description' => 'edesc'
          },
          'servers' => [
            {
              'url' => 'http://op',
              'variables' => {
                'v1' => { 'default' => 'v' }
              }
            }
          ]
        }
      }
    }

    out = Cdd::Routes::Emitter.emit(ir)
    assert_match(/@op_server/, out)
  end

  def test_routes_emit_ternaries
    ir = Cdd::IR.new
    ir.openapi_spec['servers'] = [
      { 'url' => 'http://global', 'description' => 'global',
        'variables' => {
          'v1' => { 'default' => 'v', 'enum' => nil, 'description' => nil }
        } }
    ]
    out = Cdd::Routes::Emitter.emit(ir)
    refute_nil out
  end
end
