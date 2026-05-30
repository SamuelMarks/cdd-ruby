# frozen_string_literal: true

require_relative 'spec_helper'

class RoutesBranchTest14 < Minitest::Test
  def test_routes_emit_op_server_branches
    ir = Cdd::IR.new
    ir.openapi_spec['paths'] = {
      '/p' => {
        'get' => {
          'externalDocs' => {
            'url' => 'http://ext',
            'description' => false # Falsy externalDocs description
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
      }
    }
    out = Cdd::Routes::Emitter.emit(ir)
    refute_nil out
  end
end
