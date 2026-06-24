# frozen_string_literal: true

require_relative 'spec_helper'

class ServerGenCoverageTest < Minitest::Test
  def test_server_gen_parse_multiple_params
    code = <<~RUBY
      get '/users/:user_id/posts/:post_id' do
      end
    RUBY

    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::ServerGen::Parser.parse(tokens, ir)

    op = ir.openapi_spec['paths']['/users/{user_id}/posts/{post_id}']['get']
    assert_equal 2, op['parameters'].size
    assert_equal 'user_id', op['parameters'][0]['name']
    assert_equal 'post_id', op['parameters'][1]['name']
  end

  def test_server_gen_parse_branches
    code = <<~RUBY
      get('/users/:id')
      # some other code
    RUBY
    ir = Cdd::IR.new
    # Prepopulate the path parameter to trigger the "next if" branch at line 33
    ir.openapi_spec['paths'] = {
      '/users/{id}' => {
        'get' => {
          'parameters' => [{ 'name' => 'id', 'in' => 'path' }]
        }
      }
    }
    tokens = Ripper.lex(code)
    Cdd::ServerGen::Parser.parse(tokens, ir)

    # line 21: `current_method = token[2] if next_token && next_token[1] == :on_sp`
    # The `get('/users/:id')` doesn't have a space after `get`, so next_token is `on_lparen`, hitting the `else` (false) branch of `if next_token && next_token[1] == :on_sp`.

    # Also to ensure we hit line 33's true branch:
    # A subsequent path that does have a space:
    code2 = <<~RUBY
      get '/users/:id'
    RUBY
    tokens2 = Ripper.lex(code2)
    Cdd::ServerGen::Parser.parse(tokens2, ir)

    op = ir.openapi_spec['paths']['/users/{id}']['get']
    assert_equal 1, op['parameters'].size
  end

  def test_emit_server_with_db
    ir = Cdd::IR.new
    ir.openapi_spec['paths'] = {
      '/users' => {
        'get' => { 'operationId' => 'listUsers', 'responses' => {} },
        'post' => { 'operationId' => 'createUser', 'responses' => {} }
      },
      '/users/{id}' => {
        'put' => { 'operationId' => 'updateUser', 'parameters' => [{ 'name' => 'id', 'in' => 'path' }], 'responses' => {} },
        'delete' => { 'operationId' => 'deleteUser', 'parameters' => [{ 'name' => 'id', 'in' => 'path' }], 'responses' => {} },
        'trace' => { 'operationId' => 'traceUser', 'responses' => {} }
      },
      '/users/unsupported/action' => {
        'put' => { 'operationId' => 'putUnsupported', 'responses' => {} },
        'delete' => { 'operationId' => 'deleteUnsupported', 'responses' => {} }
      }
    }
    ir.openapi_spec['components'] = {
      'schemas' => {
        'User' => {
          'type' => 'object',
          'properties' => {
            'id' => { 'type' => 'integer' },
            'name' => { 'type' => 'string' },
            'email' => { 'type' => 'string' },
            'phone' => { 'type' => 'string' },
            'isActive' => { 'type' => 'boolean' },
            'age' => { 'type' => 'integer' },
            'parent_id' => { 'type' => 'integer' },
            'companyId' => { 'type' => 'integer' },
            'other' => { 'type' => 'string' }
          }
        }
      },
      'securitySchemes' => {
        'ApiKeyAuth' => {
          'type' => 'apiKey',
          'in' => 'header',
          'name' => 'X-API-KEY'
        }
      }
    }

    options = { with_ephemeral: true, with_seed: true, tests: true, output: 'emit_test_out' }

    # Needs to pass an actual structure
    File.write('dummy_spec_for_emit.json', ir.openapi_spec.to_json)
    options[:input] = 'dummy_spec_for_emit.json'
    FileUtils.mkdir_p('emit_test_out')

    # Just run the raw emitter method directly to get the code string, bypassing writing to disk
    Cdd::ServerGen::Emitter.emit_server(options)

    # Read modular files
    db_code = File.read(File.join('emit_test_out', 'config', 'database.rb'))
    dao_code = File.read(File.join('emit_test_out', 'daos', 'user_dao.rb'))
    seeder_code = File.read(File.join('emit_test_out', 'config', 'seeder.rb'))
    server_code = File.read(File.join('emit_test_out', 'server.rb'))

    # Actually trigger the tests emitter explicitly to ensure coverage is collected locally
    test_code = Cdd::Tests::Emitter.emit(ir, options)

    assert db_code.include?('class DatabaseConnection')
    assert dao_code.include?('class ConcreteUserDao < AbstractUserDao')
    assert seeder_code.include?('module Seeder')
    assert server_code.include?('if defined?(DatabaseConnection) && (ENV[\'DATABASE_URL\'] || ENV[\'EPHEMERAL_DB\'] == \'true\')')

    assert test_code.include?('class DatabaseConnectionTest')

    File.delete('dummy_spec_for_emit.json')
    FileUtils.rm_rf('emit_test_out')
  end
end
