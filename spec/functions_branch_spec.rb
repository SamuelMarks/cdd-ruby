# frozen_string_literal: true

require_relative 'spec_helper'

class FunctionsBranchTest < Minitest::Test
  def test_emit_api_client_skip_refs_and_meta
    ir = Cdd::IR.new
    ir.openapi_spec['paths'] = {
      '/skipped' => {
        '$ref' => '#/paths/other'
      },
      '/meta' => {
        'summary' => 'Path summary',
        'description' => 'Path description',
        'servers' => [],
        'parameters' => [],
        'get' => {
          'operationId' => 'getMeta',
          'parameters' => [
            { '$ref' => '#/components/parameters/MyParam' }
          ]
        }
      }
    }

    out = Cdd::Functions::Emitter.emit(ir)
    refute_match(/skipped/, out)
    assert_match(/def getMeta\n/, out)
  end

  def test_parse_api_client_args_else
    code = <<~RUBY
      class ApiClient
        # @api_client GET /users/{id}
        def get_user(id:)
        end
      #{'  '}
        # @api_client GET /missing
        def get_missing(id:)
        end
      end
    RUBY
    ir = Cdd::IR.new

    # Missing operation method
    ir.openapi_spec['paths'] = {
      '/users/{id}' => {
        'get' => {
          'parameters' => [{ 'name' => 'id', 'in' => 'path' }]
        }
      },
      '/missing' => {}
    }

    tokens = Ripper.lex(code)
    Cdd::Functions::Parser.parse(tokens, ir)
  end
end
