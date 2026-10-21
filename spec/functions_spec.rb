# frozen_string_literal: true

require_relative 'spec_helper'

class FunctionsTest < Minitest::Test
  def test_emit_api_client
    ir = Cdd::IR.new
    ir.openapi_spec['paths'] = {
      '/users/{id}' => {
        'get' => {
          'operationId' => 'getUser',
          'summary' => 'Gets a user',
          'parameters' => [{ 'name' => 'id' }],
          'responses' => { '200' => { 'description' => 'OK' } }
        }
      }
    }

    out = Cdd::Functions::Emitter.emit(ir)
    assert_match(/class ApiClient/, out)
    assert_match(/def getUser\(id: nil\)/, out)
    assert_match(%r{# @api_client GET /users/\{id\}}, out)
  end

  def test_emit_api_client_with_body
    ir = Cdd::IR.new
    ir.openapi_spec['paths'] = {
      '/posts' => {
        'post' => {
          'operationId' => 'createPost',
          'requestBody' => {
            'content' => { 'application/json' => {} }
          },
          'responses' => { '201' => { 'description' => 'Created' } }
        }
      }
    }

    out = Cdd::Functions::Emitter.emit(ir)
    assert_match(/def createPost\(body: nil\)/, out)
  end

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
    assert_match(/def getMeta
/, out)
  end

  def test_parse_api_client
    code = <<~RUBY
      class ApiClient
        # @api_client GET /posts
        def get_posts
        end
      end
    RUBY
    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Functions::Parser.parse(tokens, ir)

    assert ir.openapi_spec['paths']['/posts']
    assert ir.openapi_spec['paths']['/posts']['get']
    assert_equal 'OK', ir.openapi_spec['paths']['/posts']['get']['responses']['200']['description']
  end

  def test_parse_api_client_args
    code = <<~RUBY
      class ApiClient
        # @api_client GET /users/{id}
        def get_user(id:, filter: nil, body: nil)
        end
      end
    RUBY
    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Functions::Parser.parse(tokens, ir)

    op = ir.openapi_spec['paths']['/users/{id}']['get']
    assert op['parameters']
    assert_equal 'id', op['parameters'][0]['name']
    assert_equal 'path', op['parameters'][0]['in']
    assert_equal 'filter', op['parameters'][1]['name']
    assert_equal 'query', op['parameters'][1]['in']
    assert op['requestBody']
  end

  def test_parse_api_client_existing_params_and_missing_op
    code = <<~RUBY
      class ApiClient
        # @api_client GET /users/{id}
        def get_user(id:)
        end

        # @api_client GET /missing
        def get_missing(id:)
        end
      end
    RUBY
    ir = Cdd::IR.new
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
    assert_equal 1, ir.openapi_spec['paths']['/users/{id}']['get']['parameters'].size
  end

  def test_parse_api_client_no_comment
    code = <<~RUBY
      class ApiClient
        def some_method(arg:)
        end
      end
    RUBY
    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Functions::Parser.parse(tokens, ir)
    assert_empty(ir.openapi_spec['paths'] || {})

    verbs_ir = Cdd::IR.new
    verbs_ir.openapi_spec['paths'] = {
      '/items' => {
        'get' => { 'operationId' => 'list_items' },
        'post' => { 'operationId' => 'create_item', 'requestBody' => { 'content' => { 'application/json' => {} } } },
        'put' => { 'operationId' => 'replace_item' },
        'delete' => { 'operationId' => 'delete_item' },
        'patch' => { 'operationId' => 'patch_item' }
      }
    }
    emitted_code = Cdd::Functions::Emitter.emit(verbs_ir)
    assert RubyVM::InstructionSequence.compile(emitted_code)
    roundtrip_ir = Cdd::IR.new
    Cdd::Functions::Parser.parse(Ripper.lex(emitted_code), roundtrip_ir)
    assert_equal %w[get post put delete patch].sort, roundtrip_ir.openapi_spec['paths']['/items'].keys.sort
  end
end
