# frozen_string_literal: true

require_relative 'spec_helper'

class TestsBranchTest2 < Minitest::Test
  def test_tests_branches
    ir = Cdd::IR.new
    ir.openapi_spec['paths'] = {
      '/test' => {
        '$ref' => '#/a/b',
        'summary' => 's'
      },
      '/test2' => {
        'get' => {
          # no operationId to cover line 25
          'parameters' => [
            { 'name' => 'status', 'schema' => { 'type' => 'string' } }
          ]
        },
        'summary' => 'sum',
        'description' => 'desc',
        'servers' => [],
        'parameters' => []
      }
    }

    out = Cdd::Tests::Emitter.emit(ir)
    refute_nil out
  end
end
