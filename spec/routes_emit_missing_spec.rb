# frozen_string_literal: true

require_relative 'spec_helper'

class RoutesEmitMissingTest < Minitest::Test
  def test_routes_emit_missing_lines
    ir = Cdd::IR.new
    ir.openapi_spec['servers'] = [{ 'url' => 'http://test', 'description' => 'Test server' }]
    ir.openapi_spec['security'] = [{ 'oauth2' => %w[read write] }]

    op = {
      'parameters' => [
        { 'name' => 'id', 'in' => 'query', 'required' => true, 'schema' => { 'type' => 'integer' },
          'description' => 'ID param' }
      ],
      'requestBody' => {
        'description' => 'Body desc',
        'content' => {
          'application/json' => {
            'schema' => { '$ref' => '#/components/schemas/MyInput' }
          }
        }
      },
      'responses' => {
        '201' => {
          'description' => 'Created',
          'content' => {
            'application/json' => {
              'schema' => { '$ref' => '#/components/schemas/MyOutput' }
            }
          }
        },
        '400' => {
          'description' => 'Bad Request'
        }
      },
      'security' => [
        { 'apikey' => [] }
      ]
    }

    ir.openapi_spec['paths'] = {
      '/test' => {
        'post' => op
      }
    }

    out = Cdd::Routes::Emitter.emit(ir)
    assert_match(%r{# @server http://test Test server}, out)
    assert_match(/# @security oauth2 read, write/, out)
    assert_match(/# @param id \[integer\] in:query required:true ID param/, out)
    assert_match(%r{# @request_body \[MyInput\] application/json Body desc}, out)
    assert_match(%r{# @response 201 \[MyOutput\] application/json Created}, out)
    assert_match(/# @response 400 Bad Request/, out)
    assert_match(/# @security apikey/, out)
  end
end
