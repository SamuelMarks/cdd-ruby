# frozen_string_literal: true

require_relative 'spec_helper'

class RoutesBranchTest15 < Minitest::Test
  def test_routes_emit_params_request_bodies
    ir = Cdd::IR.new
    ir.openapi_spec['paths'] = {
      '/test4' => {
        'get' => {
          'parameters' => [
            {
              'name' => 'p1',
              'in' => 'query',
              'schema' => { 'type' => 'string' },
              'examples' => {
                'e2' => { 'value' => 'literal' } # falsy $ref for param example
              }
            }
          ],
          'requestBody' => {
            'content' => {
              'application/json' => {
                'schema' => { 'type' => 'object' }, # falsy $ref for schema
                'examples' => {
                  'e2' => { 'value' => 'literal' } # falsy $ref for request body example
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
