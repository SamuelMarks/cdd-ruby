# frozen_string_literal: true

require_relative 'spec_helper'
require 'tempfile'
require 'tmpdir'

class ServerGenTest < Minitest::Test
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

  def test_server_gen_parse_parens_and_existing_params
    code = <<~RUBY
      get('/users/:id')
      # some other code
    RUBY
    ir = Cdd::IR.new
    ir.openapi_spec['paths'] = {
      '/users/{id}' => {
        'get' => {
          'parameters' => [{ 'name' => 'id', 'in' => 'path' }]
        }
      }
    }
    tokens = Ripper.lex(code)
    Cdd::ServerGen::Parser.parse(tokens, ir)

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

    Dir.mktmpdir do |dir|
      spec_path = File.join(dir, 'spec_for_emit.json')
      out_dir = File.join(dir, 'emit_test_out')
      File.write(spec_path, ir.openapi_spec.to_json)
      options = { with_ephemeral: true, with_seed: true, tests: true, output: out_dir, input: spec_path }

      Cdd::ServerGen::Emitter.emit_server(options)

      db_code = File.read(File.join(out_dir, 'config', 'database.rb'))
      dao_code = File.read(File.join(out_dir, 'daos', 'user_dao.rb'))
      seeder_code = File.read(File.join(out_dir, 'config', 'seeder.rb'))
      server_code = File.read(File.join(out_dir, 'server.rb'))

      test_code = Cdd::Tests::Emitter.emit(ir, options)

      assert db_code.include?('class DatabaseConnection')
      assert dao_code.include?('class ConcreteUserDao < AbstractUserDao')
      assert seeder_code.include?('module Seeder')
      assert server_code.include?("if defined?(DatabaseConnection) && (ENV['DATABASE_URL'] || ENV['EPHEMERAL_DB'] == 'true')")
      assert test_code.include?('class DatabaseConnectionTest')
      assert RubyVM::InstructionSequence.compile(test_code)
      Dir.glob(File.join(out_dir, '**', '*.rb')).each do |rb_file|
        assert RubyVM::InstructionSequence.compile(File.read(rb_file)), "Invalid syntax in #{rb_file}"
      end
    end
  end

  def test_server_emit_metadata_and_mcp_routes
    openapi = {
      'openapi' => '3.0.0',
      'info' => {
        'title' => 'Title',
        'version' => '1.0',
        'description' => 'Desc'
      },
      'servers' => [
        {
          'url' => 'http://test',
          'description' => 'Test Server',
          'variables' => {
            'var1' => { 'default' => 'a', 'enum' => %w[a b] }
          }
        }
      ],
      'components' => {
        'securitySchemes' => {
          'ApiAuth' => { 'type' => 'apiKey' }
        },
        'schemas' => {
          'MyObj' => {
            'type' => 'object',
            'properties' => { 'p1' => { 'type' => 'string' } },
            'discriminator' => {
              'propertyName' => 'type',
              'mapping' => { 'a' => 'A' }
            },
            'xml' => { 'name' => 'obj' }
          }
        }
      },
      'paths' => {
        '/test/{id}' => {
          'get' => {
            'operationId' => 'myOp',
            'summary' => 'sum',
            'description' => 'desc',
            'deprecated' => true,
            'parameters' => [
              { 'name' => 'p1', 'in' => 'path', 'required' => true, 'schema' => { 'type' => 'integer' } }
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
    }

    file = Tempfile.new(['openapi', '.json'])
    file.write(openapi.to_json)
    file.close

    Dir.mktmpdir do |out_dir|
      Cdd::ServerGen::Emitter.emit_server(input: file.path, output: out_dir)

      models_out = File.read(File.join(out_dir, 'models', 'myobj.rb'))
      mcp_out = File.read(File.join(out_dir, 'routes', 'mcp_routes.rb'))

      assert_match(/Discriminator/, models_out)
      assert_match(%r{roots/list}, mcp_out)
      assert_match(%r{resources/templates/list}, mcp_out)
      assert_match(%r{sampling/createMessage}, mcp_out)
    end
    file.unlink
  end

  def test_server_emit_optional_fields
    openapi = {
      'openapi' => '3.0.0',
      'info' => {},
      'servers' => [
        { 'url' => 'http://test', 'variables' => nil },
        { 'url' => 'http://test2', 'variables' => { 'v' => { 'default' => 'd', 'enum' => nil } } }
      ],
      'components' => {
        'securitySchemes' => false,
        'schemas' => {
          'S1' => {
            'xml' => { 'name' => 's' },
            'discriminator' => false
          },
          'S2' => {
            'properties' => { 'p' => { 'type' => 'string' } },
            'discriminator' => {
              'propertyName' => 'p',
              'mapping' => nil
            }
          }
        }
      },
      'paths' => {
        '/p' => {
          'get' => {
            'parameters' => [
              { 'name' => 'p1', 'in' => 'query', 'required' => false }
            ],
            'requestBody' => {
              'content' => {
                'text/plain' => {}
              }
            }
          },
          'post' => {
            'requestBody' => {}
          }
        }
      }
    }

    file = Tempfile.new(['openapi', '.json'])
    file.write(openapi.to_json)
    file.close

    Dir.mktmpdir do |out_dir|
      Cdd::ServerGen::Emitter.emit_server(input: file.path, output: out_dir)
      assert File.exist?(File.join(out_dir, 'server.rb'))
    end
    file.unlink

    schemas = { 'Category' => {}, 'Address' => {}, 'Pet' => {} }
    assert_equal 'Category', Cdd::ServerGen::Emitter.resolve_route_model_name('/api/v1/categories/{id}', schemas)
    assert_equal 'Address', Cdd::ServerGen::Emitter.resolve_route_model_name('/v2/addresses', schemas)
    assert_equal 'categories', Cdd::TokenScanner.pluralize('Category')
    assert_equal 'addresses', Cdd::TokenScanner.pluralize('Address')
    assert_equal 'days', Cdd::TokenScanner.pluralize('Day')
    sample_schema = {
      'properties' => {
        'id' => { 'type' => 'integer' },
        'active' => { 'type' => 'boolean' },
        'tags' => { 'type' => 'array' },
        'title' => { 'type' => 'string' }
      }
    }
    assert_includes Cdd::TokenScanner.sample_body_hash_literal(sample_schema, symbol_keys: true), 'id: 1, active: true'
    assert_includes Cdd::TokenScanner.sample_body_hash_literal(sample_schema, symbol_keys: false), "'id' => 1"
  end
end
