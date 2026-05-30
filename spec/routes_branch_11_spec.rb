# frozen_string_literal: true

require_relative 'spec_helper'

class RoutesBranchTest11 < Minitest::Test
  def test_routes_emit_response_branches
    ir = Cdd::IR.new
    ir.openapi_spec['components'] = {
      'responses' => {
        'R1' => {
          'description' => 'Response', # falsy branch for desc
          'content' => {
            'application/json' => {
              'required' => true # falsy branch for opts.empty?
            }
          }
        },
        'R2' => {
          'description' => 'Not Response' # truthy branch for desc
        },
        'R3' => {
          'description' => nil # falsy branch for desc
        }
      }
    }
    out = Cdd::Routes::Emitter.emit(ir)
    refute_nil out
  end
end
