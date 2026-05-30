# frozen_string_literal: true

require_relative 'spec_helper'

class RoutesBranchTest16 < Minitest::Test
  def test_routes_emit_encoding_branches
    ir = Cdd::IR.new
    ir.openapi_spec['paths'] = {
      '/test' => {
        'get' => {
          'requestBody' => {
            'content' => {
              'application/json' => {
                'encoding' => {
                  'p1' => {
                    'headers' => {
                      'h1' => { 'value' => 'literal' }
                    },
                    'description' => 'desc',
                    'explode' => false,
                    'allowReserved' => false
                  },
                  'p2' => {
                    # completely empty, will make enc_opts.empty? true
                  }
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
