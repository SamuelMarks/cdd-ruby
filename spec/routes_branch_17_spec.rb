# frozen_string_literal: true

require_relative 'spec_helper'

class RoutesBranchTest17 < Minitest::Test
  def test_routes_emit_response_details
    ir = Cdd::IR.new
    ir.openapi_spec['paths'] = {
      '/test' => {
        'get' => {
          'responses' => {
            '200' => {
              'content' => {
                'application/json' => {
                  'examples' => {
                    'e1' => { 'value' => 'val' } # falsy $ref (line 317)
                  }
                }
              }
            },
            '400' => {
              'description' => 'Response', # falsy ternary condition (line 327)
              'badRequest' => true # truthy badRequest (line 325), so opts not empty (line 326)
            }
          }
        }
      }
    }
    out = Cdd::Routes::Emitter.emit(ir)
    refute_nil out
  end
end
