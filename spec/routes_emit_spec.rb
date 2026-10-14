# frozen_string_literal: true

require_relative 'spec_helper'

class RoutesEmitTest < Minitest::Test
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

  def test_routes_emit_servers_and_variables
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

    ir2 = Cdd::IR.new
    ir2.openapi_spec['servers'] = [
      { 'url' => 'http://global', 'description' => 'global',
        'variables' => {
          'v1' => { 'default' => 'v', 'enum' => nil, 'description' => nil },
          'v2' => { 'default' => 'v', 'enum' => false, 'description' => false }
        } }
    ]
    out2 = Cdd::Routes::Emitter.emit(ir2)
    assert_includes out2, '# @server http://global global'
    assert_includes out2, '# @server_var http://global v1 v'
    assert_includes out2, '# @server_var http://global v2 v'
  end

  def test_routes_emit_responses_and_security
    ir = Cdd::IR.new
    ir.openapi_spec['servers'] = [{ 'url' => 'http://test', 'description' => 'Test server' }]
    ir.openapi_spec['security'] = [{ 'oauth2' => %w[read write] }]

    op = {
      'parameters' => [
        { 'name' => 'id', 'in' => 'query', 'required' => true, 'schema' => { 'type' => 'integer' },
          'description' => 'ID param' },
        { 'name' => 'userId', 'in' => 'query', 'schema' => { '$ref' => '#/components/schemas/User' } }
      ],
      'requestBody' => {
        'description' => 'Body desc',
        'content' => {
          'application/json' => {
            'schema' => { '$ref' => '#/components/schemas/MyInput' }
          }
        }
      },
      'responses' => {
        '201' => {
          'description' => 'Created',
          'content' => {
            'application/json' => {
              'schema' => { '$ref' => '#/components/schemas/MyOutput' }
            }
          }
        },
        '400' => {
          'description' => 'Bad Request'
        }
      },
      'security' => [
        { 'apikey' => [] }
      ]
    }

    ir.openapi_spec['paths'] = { '/test' => { 'post' => op } }

    out = Cdd::Routes::Emitter.emit(ir)
    assert_match(%r{# @server http://test Test server}, out)
    assert_match(/# @security oauth2 read, write/, out)
    assert_match(/# @param id \[integer\] in:query required:true ID param/, out)
    assert_match(/# @param userId \[User\] in:query/, out)
    assert_match(%r{# @request_body \[MyInput\] application/json Body desc}, out)
    assert_match(%r{# @response 201 \[MyOutput\] application/json Created}, out)
    assert_match(/# @response 400 Bad Request/, out)
    assert_match(/# @security apikey/, out)

    ir2 = Cdd::IR.new
    ir2.openapi_spec['paths'] = {
      '/test5' => {
        'get' => {
          'responses' => {
            '200' => {
              'content' => {
                'application/json' => {
                  'schema' => { 'type' => 'string' },
                  'required' => false
                }
              },
              'description' => 'Response'
            },
            '400' => {
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

    out2 = Cdd::Routes::Emitter.emit(ir2)
    assert_includes out2, '# @response 200 [Object] application/json required:false'
    assert_includes out2, '# @response 400 [Object] application/json'
  end

  def test_routes_emit_component_responses_links_and_callbacks
    ir = Cdd::IR.new
    ir.openapi_spec['components'] = {
      'responses' => {
        'R1' => {
          'description' => 'Response',
          'content' => {
            'application/json' => {
              'required' => true
            }
          }
        },
        'R2' => {
          'description' => 'Not Response'
        },
        'R3' => {
          'description' => nil
        }
      },
      'links' => {
        'L1' => {
          'operationRef' => 'ref',
          'description' => 'desc',
          'parameters' => { 'a' => 'b' },
          'requestBody' => 'body'
        },
        'L2' => {}
      },
      'callbacks' => {
        'C1' => {
          'http://url' => {
            'post' => {
              'requestBody' => {
                'description' => false,
                'content' => { 'application/json' => { 'schema' => { 'type' => 'string' } } }
              },
              'responses' => {
                '201' => {
                  'description' => 'Response',
                  'content' => { 'application/json' => { 'schema' => { 'type' => 'string' } } }
                },
                '400' => {
                  'description' => 'Response'
                }
              }
            }
          }
        },
        'C2' => {
          'http://url' => {
            'get' => {
              'requestBody' => {
                'description' => 'desc',
                'content' => { 'application/json' => {} }
              }
            }
          }
        },
        'C3' => {
          'http://url' => {
            'get' => {
              'responses' => nil
            }
          }
        }
      }
    }
    out = Cdd::Routes::Emitter.emit(ir)
    assert_includes out, '# @component_response R1 [Object] application/json required:true'
    assert_includes out, '# @component_response R2 description:Not Response'
    assert_includes out, '# @component_response R3'
    assert_includes out, '# @component_link L1 operationRef:ref parameters.a:b requestBody:body description:desc'
    assert_includes out, '# @component_link L2'
    assert_includes out, '# @component_callback C1 http://url post'
    assert_includes out, '# @component_callback_request_body [Object] application/json desc'
    assert_includes out, '# @component_callback_response 201 [Object] application/json'
    assert_includes out, '# @component_callback_response 400'
  end

  def test_routes_emit_operation_servers_params_and_encodings
    ir = Cdd::IR.new
    ir.openapi_spec['paths'] = {
      '/p' => {
        'get' => {
          'externalDocs' => {
            'url' => 'http://ext',
            'description' => false
          },
          'servers' => [
            {
              'url' => 'http://srv',
              'variables' => {
                'v1' => {
                  'default' => 'd',
                  'enum' => ['a'],
                  'description' => 'desc'
                }
              }
            }
          ]
        }
      },
      '/test4' => {
        'get' => {
          'parameters' => [
            {
              'name' => 'p1',
              'in' => 'query',
              'schema' => { 'type' => 'string' },
              'examples' => {
                'e2' => { 'value' => 'literal' }
              }
            }
          ],
          'requestBody' => {
            'content' => {
              'application/json' => {
                'schema' => { 'type' => 'object' },
                'examples' => {
                  'e2' => { 'value' => 'literal' }
                },
                'encoding' => {
                  'p1' => {
                    'headers' => {
                      'h1' => { 'value' => 'literal' }
                    },
                    'description' => 'desc',
                    'explode' => false,
                    'allowReserved' => false
                  },
                  'p2' => {}
                }
              }
            }
          }
        }
      }
    }
    out = Cdd::Routes::Emitter.emit(ir)
    assert_includes out, '# @external_docs http://ext'
    assert_includes out, '# @op_server http://srv'
    assert_includes out, '# @op_server_var http://srv v1 d enum:a description:desc'
    assert_includes out, '# @param p1 [string] in:query'
    assert_includes out, '# @request_body [Object] application/json'
    assert_includes out, '# @request_body_encoding application/json p1 explode:false allowReserved:false description:desc'
    assert_includes out, '# @request_body_encoding application/json p2'
    assert_includes out, '# @route GET /test4'
  end

  def test_routes_emit_operation_responses_links_and_callbacks
    ir = Cdd::IR.new
    ir.openapi_spec['paths'] = {
      '/test' => {
        'get' => {
          'responses' => {
            '200' => {
              'content' => {
                'application/json' => {
                  'examples' => {
                    'e1' => { 'value' => 'val' }
                  }
                }
              },
              'links' => {
                'L1' => {
                  'operationRef' => 'ref',
                  'description' => 'desc',
                  'parameters' => { 'a' => 'b' },
                  'requestBody' => 'b'
                },
                'L2' => {}
              }
            },
            '400' => {
              'description' => 'Response',
              'badRequest' => true
            }
          },
          'callbacks' => {
            'C1' => {
              'http://url' => {
                'post' => {
                  'requestBody' => {
                    'description' => 'desc',
                    'content' => { 'application/json' => { 'schema' => { 'type' => 'string' } } }
                  },
                  'responses' => {
                    '200' => {
                      'description' => 'OK',
                      'content' => nil
                    },
                    '201' => {
                      'description' => 'desc',
                      'content' => { 'application/json' => { 'schema' => { 'type' => 'string' } } }
                    },
                    '202' => {
                      'description' => false,
                      'content' => { 'application/json' => { 'schema' => { 'type' => 'string' } } }
                    },
                    '400' => {
                      'description' => 'Response'
                    }
                  }
                }
              }
            },
            'C2' => {
              'http://url' => {
                'post' => {
                  'requestBody' => {
                    'description' => false,
                    'content' => { 'application/json' => { 'schema' => { 'type' => 'string' } } }
                  },
                  'responses' => nil
                }
              }
            }
          }
        }
      }
    }
    out = Cdd::Routes::Emitter.emit(ir)
    assert_includes out, '# @response 200 [Object] application/json'
    assert_includes out, '# @response 400 badRequest:true'
    assert_includes out, '# @link 200 L1 operationRef:ref parameters.a:b requestBody:b description:desc'
    assert_includes out, '# @link 200 L2'
    assert_includes out, '# @callback C1 http://url post'
    assert_includes out, '# @callback_response 201 [Object] application/json description:desc'
  end
end
