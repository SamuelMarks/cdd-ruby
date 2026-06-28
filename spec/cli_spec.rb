# frozen_string_literal: true

require_relative 'spec_helper'
require_relative '../src/cdd'
require_relative '../src/cli'
require 'open3'

class CliTest < Minitest::Test
  def setup
    File.write('dummy.rb', "# @route GET /hello\nclass User\nend\n")
    File.write('dummy_schema.json', '{"info":{"title":"Test API","version":"1.0.0"},"paths":{"/test":{}},"components":{"schemas":{"User":{}}}}')
    File.write('dummy.json', <<~JSON
      {
        "openapi": "3.2.0",
        "info": {
          "title": "API",
          "version": "1.0.0"
        },
        "servers": [
          {
            "url": "https://api.example.com",
            "description": "Production server",
            "variables": {
              "port": {
                "default": "443",
                "enum": ["443", "8443"]
              }
            }
          }
        ],
        "components": {
          "securitySchemes": {
            "oauth2": {
              "type": "oauth2",
              "flows": {
                "implicit": {
                  "authorizationUrl": "https://example.com/api/oauth/dialog",
                  "scopes": {
                    "write:pets": "modify pets in your account",
                    "read:pets": "read your pets"
                  }
                }
              }
            }
          },
          "schemas": {
            "User": {
              "type": "object",
              "example": {"id": 1, "name": "John Doe"},
              "discriminator": {
                "propertyName": "userType",
                "mapping": {
                  "admin": "#/components/schemas/Admin"
                }
              },
              "xml": {
                "name": "user"
              },
              "properties": {
                "id": {
                  "type": "integer"
                },
                "name": {
                  "type": "string"
                }
              }
            }
          },
          "examples": {
            "userExample": {
              "externalValue": "http://example.org/examples/user-example.json"
            }
          }
        },
        "webhooks": {
          "newPet": {
            "post": {
              "responses": {
                "200": {
                  "description": "OK"
                }
              }
            }
          }
        },
        "paths": {
          "/users/{id}": {
            "get": {
              "operationId": "getUser",
              "parameters": [
                {
                  "name": "id",
                  "in": "path",
                  "required": true,
                  "allowEmptyValue": false,
                  "style": "simple",
                  "explode": false,
                  "allowReserved": false,
                  "schema": {
                    "type": "integer"
                  }
                }
              ],
              "requestBody": {
                "required": true,
                "content": {
                  "application/json": {
                    "schema": {
                      "$ref": "#/components/schemas/User"
                    },
                    "examples": {
                      "user": {
                        "value": {"id": 1}
                      }
                    },
                    "encoding": {
                      "profileImage": {
                        "contentType": "image/png, image/jpeg",
                        "style": "form",
                        "explode": true,
                        "allowReserved": true
                      }
                    }
                  }
                }
              },
              "responses": {
                "200": {
                  "description": "OK",
                  "headers": {
                    "X-Rate-Limit": {
                      "description": "calls per hour allowed by the user",
                      "required": true,
                      "style": "simple",
                      "explode": false,
                      "schema": {
                        "type": "integer",
                        "format": "int32"
                      }
                    }
                  },
                  "content": {
                    "application/json": {
                      "schema": {
                        "$ref": "#/components/schemas/User"
                      }
                    }
                  },
                  "links": {
                    "GetUserByEmail": {
                      "operationRef": "#/paths/~1users~1{email}/get"
                    }
                  }
                }
              },
              "callbacks": {
                "myCallback": {
                  "http://notificationURL.com": {
                    "post": {
                      "requestBody": {
                        "content": {
                          "application/json": {
                            "schema": {
                              "type": "object",
                              "properties": {
                                "message": {
                                  "type": "string"
                                }
                              }
                            }
                          }
                        }
                      },
                      "responses": {
                        "200": {
                          "description": "Callback successfully processed"
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    JSON
    )
  end

  def teardown
    ['spec.json', 'docs.json', 'server.rb', 'sdk_cli.rb'].each { |f| FileUtils.rm_f(f) }
    FileUtils.rm_f('dummy.rb')
    FileUtils.rm_f('dummy.json')
    FileUtils.rm_f('dummy_schema.json')
    FileUtils.rm_rf('scaffold_test_dir')
    FileUtils.rm_rf('test_sdk_out')
    FileUtils.rm_rf('test_cli_mcp_server_out')
    FileUtils.rm_rf('test_server_out_cli')
  end

  def test_cli_version
    output = `ruby -Isrc bin/cdd-ruby --version`.strip
    assert_equal '0.0.3', output
    assert_equal 0, CDD::CLI.run(['--version'])
  end

  def test_config_to_a
    config = CDD::Config.new(
      subcommand: 'to_sdk',
      input: 'in.json',
      output: 'out_dir',
      input_dir: 'in_dir',
      no_imports: true,
      no_wrapping: true,
      no_github_actions: true,
      no_installable_package: true,
      tests: true,
      mcp: true,
      truth: 'class',
      with_ephemeral: true,
      with_seed: true,
      port: 8080,
      listen: '127.0.0.1'
    )
    expected_args = [
      'to_sdk', '-i', 'in.json', '-o', 'out_dir', '-d', 'in_dir',
      '--no-imports', '--no-wrapping', '--no-github-actions',
      '--no-installable-package', '--tests', '--mcp',
      '--truth', 'class', '--with-ephemeral', '--with-seed',
      '-p', '8080', '-l', '127.0.0.1'
    ]
    assert_equal expected_args, config.to_a
  end

  def test_cli_helpers
    # Test print_help
    assert_equal 0, CDD::CLI.run(['--help'])
    assert_equal 0, CDD::CLI.run(['from_openapi', '--help'])
    assert_equal 0, CDD::CLI.run(['to_openapi', '--help'])
    assert_equal 0, CDD::CLI.run(['to_docs_json', '--help'])
    assert_equal 0, CDD::CLI.run(['serve_json_rpc', '--help'])
    assert_equal 0, CDD::CLI.run(['mcp', '--help'])
    assert_equal 0, CDD::CLI.run(['sync', '--help'])

    # Test unknown subcommand help prints global help
    assert_equal 0, CDD::CLI.run(['unknown_command', '--help'])

    # These helpers shell out to run internally using Config objects
    config_from = CDD::Config.new(subcommand: 'to_sdk')
    assert_equal 1, CDD::CLI.generate_from_openapi(config_from)
    config_to = CDD::Config.new
    assert_equal 1, CDD::CLI.generate_to_openapi(config_to)
    config_docs = CDD::Config.new
    assert_equal 1, CDD::CLI.generate_docs_json(config_docs)

    # We can mock Cdd::Server.start to test serve_json_rpc
    original_start = Cdd::Server.method(:start)
    begin
      Cdd::Server.singleton_class.define_method(:start) { |_l, _p| nil }
      config_rpc = CDD::Config.new(port: '1234', listen: '0.0.0.0')
      assert_equal 0, CDD::CLI.serve_json_rpc(config_rpc)
    ensure
      Cdd::Server.singleton_class.define_method(:start, original_start)
    end
  end

  def test_cli_run_edge_cases
    # Test unknown command
    assert_equal 1, CDD::CLI.run(['unknown_cmd'])

    # Test missing arguments for to_openapi
    assert_equal 1, CDD::CLI.run(['to_openapi'])

    # Test missing arguments for to_docs_json
    assert_equal 1, CDD::CLI.run(['to_docs_json'])

    # Test missing arguments for from_openapi
    assert_equal 1, CDD::CLI.run(%w[from_openapi to_sdk])

    # Test unknown from_openapi subcommand
    assert_equal 1, CDD::CLI.run(['from_openapi', 'unknown_subcmd', '-i', 'dummy.json'])

    # Test missing arguments for sync
    assert_equal 1, CDD::CLI.run(['sync'])

    # Test get_arg with env
    ENV['CDD_TEST_ENV'] = 'val'
    assert_equal 'val', CDD::CLI.get_arg({}, :none, 'CDD_TEST_ENV')
    ENV.delete('CDD_TEST_ENV')
  end

  def test_cli_mcp
    Open3.popen3('ruby -Isrc bin/cdd-ruby mcp') do |stdin, stdout, _stderr, _wait_thr|
      stdin.puts '{"jsonrpc":"2.0","id":1,"method":"initialize"}'
      stdin.puts '{"jsonrpc":"2.0","method":"notifications/initialized"}'
      stdin.puts '{"jsonrpc":"2.0","id":2,"method":"tools/list"}'
      stdin.puts '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"generate_to_openapi","arguments":{"input":"dummy.rb","output":"spec.json"}}}'
      stdin.puts '{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"generate_from_openapi","arguments":{"subcommand":"to_server","input":"dummy.json","output":"test_cli_mcp_server_out"}}}'
      stdin.puts '{"jsonrpc":"2.0","id":5,"method":"prompts/list"}'
      stdin.puts '{"jsonrpc":"2.0","id":6,"method":"prompts/get","params":{"name":"generate_docs","arguments":{"filepath":"dummy.rb"}}}'
      stdin.puts '{"jsonrpc":"2.0","id":7,"method":"resources/list"}'
      stdin.puts '{"jsonrpc":"2.0","id":8,"method":"resources/read","params":{"uri":"mcp://cdd/docs"}}'
      stdin.puts '{"jsonrpc":"2.0","id":9,"method":"resources/subscribe","params":{"uri":"mcp://cdd/docs"}}'
      stdin.puts '{"jsonrpc":"2.0","id":10,"method":"logging/setLevel","params":{"level":"debug"}}'
      stdin.puts '{"jsonrpc":"2.0","id":11,"method":"ping"}'
      stdin.puts '{"jsonrpc":"2.0","id":12,"method":"completion/complete","params":{"ref":{"type":"prompt","name":"generate_docs"},"argument":{"name":"filepath","value":"du"}}}'
      stdin.puts '{"jsonrpc":"2.0","id":13,"method":"tools/call","params":{"name":"inspect_schema","arguments":{"filepath":"dummy_schema.json"}}}'
      stdin.puts '{"jsonrpc":"2.0","id":14,"method":"tools/call","params":{"name":"inspect_schema","arguments":{"filepath":"does_not_exist.json"}}}'
      stdin.puts '{"jsonrpc":"2.0","id":15,"method":"resources/templates/list"}'
      stdin.puts '{"jsonrpc":"2.0","id":16,"method":"roots/list"}'
      stdin.puts %({"jsonrpc":"2.0","id":17,"method":"sampling/createMessage","params":{"messages":[{"role":"user","content":{"type":"text","text":"test"}}]}})
      stdin.puts 'invalid json'
      stdin.close

      output_lines = stdout.read.split("\n")

      resp1 = JSON.parse(output_lines[0])
      assert_equal '2.0', resp1['jsonrpc']
      assert_equal 1, resp1['id']
      assert resp1['result']['capabilities']

      resp2 = JSON.parse(output_lines[1])
      assert_equal 2, resp2['id']
      assert !resp2['result']['tools'].empty?

      resp3 = JSON.parse(output_lines[2])
      assert_equal 3, resp3['id']
      assert_equal 'Generated successfully', resp3['result']['content'][0]['text']

      resp4 = JSON.parse(output_lines[3])
      assert_equal 4, resp4['id']
      assert_equal 'Generated successfully', resp4['result']['content'][0]['text']

      resp5 = JSON.parse(output_lines[4])
      assert_equal 5, resp5['id']
      assert !resp5['result']['prompts'].empty?

      resp6 = JSON.parse(output_lines[5])
      assert_equal 6, resp6['id']
      assert_equal 'Generate docs prompt', resp6['result']['description']

      resp7 = JSON.parse(output_lines[6])
      assert_equal 7, resp7['id']
      assert !resp7['result']['resources'].empty?

      resp8 = JSON.parse(output_lines[7])
      assert_equal 8, resp8['id']
      assert_equal '# CDD Docs', resp8['result']['contents'][0]['text']

      resp9 = JSON.parse(output_lines[8])
      assert_equal 9, resp9['id']

      resp10 = JSON.parse(output_lines[9])
      assert_equal 10, resp10['id']

      resp11 = JSON.parse(output_lines[10])
      assert_equal 11, resp11['id']

      resp12 = JSON.parse(output_lines[11])
      assert_equal 12, resp12['id']

      resp13 = JSON.parse(output_lines[12])
      assert_equal 13, resp13['id']
      assert_includes resp13['result']['content'][0]['text'], 'Schema: Test API 1.0.0'

      resp14 = JSON.parse(output_lines[14])
      assert_equal 14, resp14['id']
      assert_equal(-32_603, resp14['error']['code'])

      resp15 = JSON.parse(output_lines[15])
      assert_equal 15, resp15['id']
      assert_equal [], resp15['result']['resourceTemplates']

      resp16 = JSON.parse(output_lines[16])
      assert_equal 16, resp16['id']
      assert_equal [], resp16['result']['roots']

      resp17 = JSON.parse(output_lines[17])
      assert_equal 17, resp17['id']
      assert_equal 'sampled', resp17['result']['content']['text']

      err_resp = JSON.parse(output_lines[18])
      assert_equal(-32_700, err_resp['error']['code'])
    end
  end

  def test_cli_to_openapi
    result = Cdd::Parser.parse('dummy.rb')
    File.write('spec.json', result)
    json = JSON.parse(result)
    assert_equal '3.2.0', json['openapi']
  end

  def test_cli_from_openapi
    Cdd::Emitter.emit_server(input: 'dummy.json', output: 'test_server_out_cli', no_installable_package: true, no_github_actions: true)
    output = File.read('test_server_out_cli/routes/user_routes.rb')
    assert_match(%r{get '/users/:\w+' do}, output)
    FileUtils.rm_rf('test_server_out_cli')
  end

  def test_cli_from_openapi_sdk
    Cdd::Emitter.emit_sdk(input: 'dummy.json', output: 'test_sdk_out', no_installable_package: true,
                          no_github_actions: true)
    output = File.read('test_sdk_out/lib/client.rb')
    assert_match(/def getUser/, output)
    models_output = File.read('test_sdk_out/lib/models.rb')
    assert_match(/module Types/, models_output)
  end

  def test_cli_from_openapi_sdk_cli
    Cdd::Emitter.emit_sdk_cli(input: 'dummy.json', output: '.', no_installable_package: true, no_github_actions: true)
    output = File.read('sdk_cli.rb')
    assert_match(/Auto-generated SDK CLI/, output)
    assert_match(/getUser/, output)
  end

  def test_cli_to_docs_json
    result = Cdd::DocsJson::Emitter.emit('dummy.json', no_imports: false, no_wrapping: false)
    File.write('docs.json', result)
    json = JSON.parse(result)

    assert json.key?('endpoints')
    assert json['endpoints'].key?('/users/{id}')
    assert json['endpoints']['/users/{id}'].key?('get')

    code = json['endpoints']['/users/{id}']['get']
    assert_match(/getUser/, code)
  end

  def test_cli_scaffolding
    out_dir = 'scaffold_test_dir'
    Cdd::Emitter.emit_sdk(input: 'dummy.json', output: out_dir, tests: true)
    assert File.exist?("#{out_dir}/lib/client.rb")
    assert File.exist?("#{out_dir}/lib/models.rb")
    assert File.exist?("#{out_dir}/lib/tests.rb")
    assert File.exist?("#{out_dir}/lib/mocks.rb")
    assert File.exist?("#{out_dir}/generated_project.gemspec")
    assert File.exist?("#{out_dir}/Gemfile")
    assert File.exist?("#{out_dir}/.github/workflows/ci.yml")

    # test for server with composable tests and mocks
    Cdd::Emitter.emit_server(input: 'dummy.json', output: out_dir, tests: true)
    assert File.exist?("#{out_dir}/server.rb")
    assert File.exist?("#{out_dir}/tests/cli_parser_test.rb")
    assert File.exist?("#{out_dir}/tests/cors_and_validation_test.rb")
    assert Dir.exist?("#{out_dir}/mocks")

    # test for cli with composable tests and mocks
    Cdd::Emitter.emit_sdk_cli(input: 'dummy.json', output: out_dir, tests: true)
    assert File.exist?("#{out_dir}/sdk_cli.rb")
  end

  def test_parsers_for_coverage
    # Server parser
    ir_server = Cdd::IR.new
    code_server = "get '/foo/:id' do\nend"
    tokens_server = Ripper.lex(code_server)
    Cdd::ServerGen::Parser.parse(tokens_server, ir_server)
    assert ir_server.openapi_spec['paths']['/foo/{id}']

    # Client SDK CLI parser
    ir_cli = Cdd::IR.new
    code_cli = <<~RUBY
      case other
      end
      case command
      when 'mcp'
        puts 'mcp'
      when 'my_op'
        puts 'Calling POST /my_op/path'
      when 'other_op'
        puts 'Calling GET /other'
      end
    RUBY
    tokens_cli = Ripper.lex(code_cli)
    Cdd::ClientSdkCli::Parser.parse(tokens_cli, ir_cli)
    assert ir_cli.openapi_spec['paths']['/my_op/path']['post']
    assert ir_cli.openapi_spec['paths']['/other']['get']

    # Client SDK parser
    ir_sdk = Cdd::IR.new
    code_sdk = <<~RUBY
      class OtherClass
        def initialize
        end
      end
      class ClientSdk
        def initialize
        end
        def authorize_oauth2
        end
        def handle_webhook_evt
        end
        def my_method
          req_path = '/users'.dup
          req = Net::HTTP::Post.new(uri)
        end
      end
    RUBY
    tokens_sdk = Ripper.lex(code_sdk)
    Cdd::ClientSdk::Parser.parse(tokens_sdk, ir_sdk)
    assert ir_sdk.openapi_spec['paths']['/users']['post']
  end

  def test_supported_keys
    assert Cdd::ServerGen::Emitter._supported_keys.any?
    assert Cdd::ServerGen::Parser._supported_keys.any?
    assert Cdd::ClientSdk::Emitter._supported_keys.any?
    assert Cdd::ClientSdk::Parser._supported_keys.any?
    assert Cdd::ClientSdkCli::Emitter._supported_keys.any?
    assert Cdd::ClientSdkCli::Parser._supported_keys.any?
  end
end
