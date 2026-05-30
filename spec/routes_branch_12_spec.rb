# frozen_string_literal: true

require_relative 'spec_helper'

class RoutesBranchTest12 < Minitest::Test
  def test_routes_emit_link_branches
    ir = Cdd::IR.new
    ir.openapi_spec['components'] = {
      'links' => {
        'L1' => {
          'operationRef' => 'ref',
          'description' => 'desc',
          'parameters' => { 'a' => 'b' },
          'requestBody' => 'body'
        },
        'L2' => {}
      }
    }
    out = Cdd::Routes::Emitter.emit(ir)
    refute_nil out
  end
end
