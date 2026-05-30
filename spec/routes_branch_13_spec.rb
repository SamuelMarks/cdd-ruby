# frozen_string_literal: true

require_relative 'spec_helper'

class RoutesBranchTest13 < Minitest::Test
  def test_routes_emit_callback_branches
    ir = Cdd::IR.new
    ir.openapi_spec['components'] = {
      'callbacks' => {
        'C1' => {
          'http://url' => {
            'post' => {
              'requestBody' => {
                'description' => false,
                'content' => { 'application/json' => { 'schema' => { 'type' => 'string' } } }
              },
              'responses' => {
                '201' => {
                  'description' => 'Response',
                  'content' => { 'application/json' => { 'schema' => { 'type' => 'string' } } }
                },
                '400' => {
                  'description' => 'Response'
                }
              }
            }
          }
        },
        'C2' => {
          'http://url' => {
            'get' => {
              'requestBody' => {
                'description' => 'desc',
                'content' => { 'application/json' => {} }
              }
            }
          }
        },
        'C3' => {
          'http://url' => {
            'get' => {
              'responses' => nil
            }
          }
        }
      }
    }
    out = Cdd::Routes::Emitter.emit(ir)
    refute_nil out
  end
end
