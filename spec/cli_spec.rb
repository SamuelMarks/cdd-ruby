require_relative 'spec_helper'
require_relative '../src/cdd'

class CliTest < Minitest::Test
  def setup
    File.write("dummy.rb", "# @route GET /hello\nclass User\nend\n")
    File.write("dummy.json", <<~JSON
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
    ["spec.json", "docs.json", "server.rb", "sdk.rb", "sdk_cli.rb"].each { |f| File.delete(f) if File.exist?(f) }
    File.delete("dummy.rb") if File.exist?("dummy.rb")
    File.delete("dummy.json") if File.exist?("dummy.json")
    FileUtils.rm_rf("scaffold_test_dir") if Dir.exist?("scaffold_test_dir")
  end

  def test_cli_to_openapi
    result = Cdd::Parser.parse("dummy.rb")
    File.write("spec.json", result)
    json = JSON.parse(result)
    assert_equal "3.2.0", json["openapi"]
  end

  def test_cli_from_openapi
    Cdd::Emitter.emit_server(input: "dummy.json", output: ".", no_installable_package: true, no_github_actions: true)
    output = File.read("server.rb")
    assert_match(/get '\/users\/:\w+' do/, output)
  end

  def test_cli_from_openapi_sdk
    Cdd::Emitter.emit_sdk(input: "dummy.json", output: ".", no_installable_package: true, no_github_actions: true)
    output = File.read("sdk.rb")
    assert_match(/def getUser/, output)
  end

  def test_cli_from_openapi_sdk_cli
    Cdd::Emitter.emit_sdk_cli(input: "dummy.json", output: ".", no_installable_package: true, no_github_actions: true)
    output = File.read("sdk_cli.rb")
    assert_match(/Auto-generated SDK CLI/, output)
    assert_match(/getUser/, output)
  end

  def test_cli_to_docs_json
    result = Cdd::DocsJson::Emitter.emit("dummy.json", no_imports: false, no_wrapping: false)
    File.write("docs.json", result)
    json = JSON.parse(result)
    
    assert json.key?("endpoints")
    assert json["endpoints"].key?("/users/{id}")
    assert json["endpoints"]["/users/{id}"].key?("get")
    
    code = json["endpoints"]["/users/{id}"]["get"]
    assert_match(/getUser/, code)
  end

  def test_cli_scaffolding
    out_dir = "scaffold_test_dir"
    Cdd::Emitter.emit_sdk(input: "dummy.json", output: out_dir)
    assert File.exist?("#{out_dir}/sdk.rb")
    assert File.exist?("#{out_dir}/generated_project.gemspec")
    assert File.exist?("#{out_dir}/Gemfile")
    assert File.exist?("#{out_dir}/.github/workflows/ci.yml")
  end

  def test_parsers_for_coverage
    # Server parser
    ir_server = Cdd::IR.new
    code_server = "get '/foo/:id' do\nend"
    tokens_server = Ripper.lex(code_server)
    Cdd::ServerGen::Parser.parse(tokens_server, ir_server)
    assert ir_server.openapi_spec["paths"]["/foo/{id}"]

    # Client SDK CLI parser
    ir_cli = Cdd::IR.new
    code_cli = "case command\nwhen 'my_op'\nputs 'hi'\nend"
    tokens_cli = Ripper.lex(code_cli)
    Cdd::ClientSdkCli::Parser.parse(tokens_cli, ir_cli)
    assert ir_cli.openapi_spec["paths"]["/my_op"]

    # Client SDK parser
    ir_sdk = Cdd::IR.new
    code_sdk = "def my_method\nend"
    tokens_sdk = Ripper.lex(code_sdk)
    Cdd::ClientSdk::Parser.parse(tokens_sdk, ir_sdk)
    assert ir_sdk.openapi_spec["paths"]["/my_method"]
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
