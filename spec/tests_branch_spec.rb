# frozen_string_literal: true

require_relative 'spec_helper'

class TestsBranchTest < Minitest::Test
  def test_tests_branches
    ir = Cdd::IR.new

    ir.openapi_spec['paths'] = {
      '/test' => {
        'get' => {
          'operationId' => 'myOp',
          'parameters' => [
            { 'name' => 'p1', 'schema' => { 'type' => 'integer' } },
            { 'name' => 'p2', 'schema' => { 'type' => 'boolean' } },
            { 'name' => 'p3', 'schema' => { 'type' => 'array', 'items' => { 'type' => 'string' } } },
            { 'name' => 'p4', 'schema' => { '$ref' => '#/components/schemas/Obj' } }
          ],
          'requestBody' => {
            'content' => {
              'application/json' => {
                'schema' => { 'type' => 'string' }
              }
            }
          }
        }
      }
    }

    out = Cdd::Tests::Emitter.emit(ir)
    assert_match(/def test_myOp/, out)
  end
end
