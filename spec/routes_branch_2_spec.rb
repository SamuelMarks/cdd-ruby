# frozen_string_literal: true

require_relative 'spec_helper'

class RoutesBranchTest9 < Minitest::Test
  def test_routes_emit_examples
    ir = Cdd::IR.new
    ir.openapi_spec['paths'] = {
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

    out = Cdd::Routes::Emitter.emit(ir)
    refute_nil out
  end
end
