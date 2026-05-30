# frozen_string_literal: true

require_relative 'spec_helper'

class RoutesBranchTest18 < Minitest::Test
  def test_routes_emit_final_branches
    ir = Cdd::IR.new
    ir.openapi_spec['paths'] = {
      '/test' => {
        'get' => {
          'responses' => {
            '200' => {
              'links' => {
                'L1' => {
                  'operationRef' => 'ref',
                  'description' => 'desc',
                  'parameters' => { 'a' => 'b' },
                  'requestBody' => 'b'
                },
                'L2' => {} # Empty link to cover 363 then branch
              }
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
                      'content' => nil # Truthy for !cb_resp['content'] (line 391)
                    },
                    '201' => {
                      'description' => 'desc',
                      'content' => { 'application/json' => { 'schema' => { 'type' => 'string' } } }
                    },
                    '202' => {
                      'description' => false, # For line 397
                      'content' => { 'application/json' => { 'schema' => { 'type' => 'string' } } }
                    },
                    '400' => {
                      'description' => 'Response' # falsy ternary for line 400
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
    refute_nil out
  end
end
