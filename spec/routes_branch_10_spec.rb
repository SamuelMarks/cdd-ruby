# frozen_string_literal: true

require_relative 'spec_helper'

class RoutesBranchTest10 < Minitest::Test
  def test_routes_emit_servers_edge
    ir = Cdd::IR.new
    ir.openapi_spec['servers'] = [
      { 'url' => 'http://global', 'description' => 'global',
        'variables' => {
          'v1' => { 'default' => 'v', 'enum' => nil, 'description' => nil },
          'v2' => { 'default' => 'v', 'enum' => false, 'description' => false }
        } }
    ]
    out = Cdd::Routes::Emitter.emit(ir)
    refute_nil out
  end
end
