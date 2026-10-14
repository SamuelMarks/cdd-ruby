# frozen_string_literal: true

require_relative 'spec_helper'

class TestsTest < Minitest::Test
  def test_emit_tests_routes
    ir = Cdd::IR.new
    ir.openapi_spec['paths'] = {
      '/users/{id}' => {
        'get' => {
          'operationId' => 'getUser',
          'summary' => 'Gets a user',
          'parameters' => [{ 'name' => 'id', 'schema' => { 'type' => 'integer' } }],
          'responses' => { '200' => { 'description' => 'OK' } }
        },
        'put' => {
          'operationId' => 'updateUser',
          'parameters' => [{ 'name' => 'id', 'schema' => { 'type' => 'integer' } }],
          'requestBody' => {
            'content' => {
              'application/json' => { 'schema' => { 'type' => 'object' } }
            }
          },
          'responses' => { '204' => { 'description' => 'No Content' } }
        }
      },
      '/posts' => {
        'post' => {
          'operationId' => 'createPost',
          'requestBody' => {
            'content' => {
              'application/json' => { 'schema' => { 'type' => 'object' } }
            }
          },
          'responses' => { '201' => { 'description' => 'Created' } }
        }
      }
    }

    out = Cdd::Tests::Emitter.emit(ir)

    assert_match(/class ApiClientTest < Minitest::Test/, out)
    assert_match(/def test_getUser/, out)
    assert_match(%r{client = ClientSdk.new\('http://localhost:8080/v2'\)}, out)
    assert_match(/assert_equal '200', client\.last_response\.code/, out)

    assert_match(/def test_updateUser/, out)
    assert_match(/assert_equal '204', client\.last_response\.code/, out)

    assert_match(/def test_createPost/, out)
    assert_match(/assert_equal '201', client\.last_response\.code/, out)
  end

  def test_parse_tests
    code = <<~RUBY
      class ApiClientTest < Minitest::Test
        # @api_test GET /posts
        def test_get_posts
        end
      end
    RUBY
    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Tests::Parser.parse(tokens, ir)

    assert ir.openapi_spec['paths']['/posts']
    assert ir.openapi_spec['paths']['/posts']['get']
    assert_equal 'OK', ir.openapi_spec['paths']['/posts']['get']['responses']['200']['description']
  end

  def test_emit_tests_parameter_types_and_refs
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

  def test_emit_tests_without_operation_id_and_skip_ref_paths
    ir = Cdd::IR.new
    ir.openapi_spec['paths'] = {
      '/test' => {
        '$ref' => '#/a/b',
        'summary' => 's'
      },
      '/test2' => {
        'get' => {
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
    refute_includes out, '/test '
    assert_includes out, 'def test_get_test2'
    assert_includes out, "status: 'available'"
  end

  def test_emit_status_param_in_server_mode
    code = <<~RUBY
      # @param status [string] in:query
      # @route GET /test
      def test_route
      end
    RUBY

    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Docstrings::Parser.parse(tokens, ir)

    out = Cdd::Tests::Emitter.emit(ir, { server: true })
    assert_match(/status=available/, out)
  end

  def test_emit_server_path_param
    code = <<~RUBY
      # @param user_id [integer] in:path
      # @route GET /users/{user_id}
      def get_user
      end
    RUBY

    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Docstrings::Parser.parse(tokens, ir)

    out = Cdd::Tests::Emitter.emit(ir, { server: true })
    assert_match(/sinatra_path\.gsub!\('\{user_id\}', '1'\)/, out)
  end
end
