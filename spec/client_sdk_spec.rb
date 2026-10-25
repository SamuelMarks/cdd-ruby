# frozen_string_literal: true

require_relative 'spec_helper'
require 'tempfile'
require 'json'
require 'fileutils'

class ClientSdkTest < Minitest::Test
  def test_client_sdk_emit_oauth
    openapi = {
      'openapi' => '3.0.0',
      'components' => {
        'securitySchemes' => {
          'oauth' => { 'type' => 'oauth2' },
          'apikey' => { 'type' => 'apiKey' }
        }
      }
    }
    file = Tempfile.new(['openapi', '.json'])
    file.write(openapi.to_json)
    file.close
    out = Cdd::ClientSdk::Emitter.emit_sdk(input: file.path)
    assert_match(/authorize_oauth2/, out)
    file.unlink
  end

  def test_client_sdk_emit_encoding_and_callbacks
    openapi = {
      'openapi' => '3.0.0',
      'info' => { 'title' => 'Title' },
      'components' => {
        'schemas' => {
          'A' => { 'properties' => { 'p' => {} } }
        }
      },
      'paths' => {
        '/test' => {
          'get' => {
            'requestBody' => {
              'content' => {
                'application/json' => {
                  'encoding' => {
                    'a' => { 'contentType' => 'text/plain', 'headers' => { 'b' => 'c' }, 'style' => 'simple', 'explode' => true, 'allowReserved' => false }
                  }
                }
              }
            },
            'responses' => {
              '200' => { 'content' => { 'application/json' => {} } }
            },
            'callbacks' => {
              'cb' => { 'http://cb' => { 'post' => { 'requestBody' => { 'content' => { 'a' => {} } } } } }
            }
          }
        }
      }
    }
    file = Tempfile.new(['openapi', '.json'])
    file.write(openapi.to_json)
    file.close
    out = Cdd::ClientSdk::Emitter.emit_sdk(input: file.path)
    assert_includes out, 'def get__test(params = {})'
    assert_includes out, 'Encoding a: contentType=text/plain style=simple explode=true allowReserved=false'
    file.unlink
  end

  def test_client_sdk_emit_default_operation_names_and_body_params
    openapi = {
      'openapi' => '3.0.0',
      'paths' => {
        '/test' => {
          'get' => {
            'parameters' => [
              { 'name' => 'p2', 'in' => 'body', 'schema' => { 'type' => 'array' } },
              { 'name' => 'p3', 'in' => 'body', 'schema' => { 'type' => 'string' } }
            ],
            'requestBody' => {
              'content' => { 'application/json' => { 'schema' => { 'type' => 'string' } } }
            }
          }
        }
      },
      'components' => nil
    }
    file = Tempfile.new(['openapi', '.json'])
    file.write(openapi.to_json)
    file.close

    out_dir = Dir.mktmpdir
    out = Cdd::ClientSdk::Emitter.emit_sdk(input: file.path, output: out_dir, tests: true, no_github_actions: true, no_installable_package: true)
    assert_includes out, 'def get__test(params = {})'
    assert File.exist?(File.join(out_dir, 'spec', 'integration_spec.rb'))

    file.unlink
    FileUtils.rm_rf(out_dir)
  end

  def test_client_sdk_emit_nil_properties_and_examples
    openapi = {
      'openapi' => '3.0.0',
      'components' => {
        'schemas' => {
          'A' => {
            'example' => false,
            'properties' => nil
          }
        }
      }
    }
    file = Tempfile.new(['openapi', '.json'])
    file.write(openapi.to_json)
    file.close
    out = Cdd::ClientSdk::Emitter.emit_sdk(input: file.path)
    assert_includes out, 'class A'
    file.unlink

    openapi2 = {
      'openapi' => '3.0.0',
      'paths' => {
        '/test' => {
          'get' => {
            'summary' => 'Summary String',
            'requestBody' => {
              'content' => nil
            },
            'parameters' => [
              { 'name' => 'status', 'in' => 'query', 'schema' => { 'type' => 'string' } }
            ]
          }
        }
      }
    }
    file2 = Tempfile.new(['openapi', '.json'])
    file2.write(openapi2.to_json)
    file2.close
    out_dir2 = Dir.mktmpdir
    out2 = Cdd::ClientSdk::Emitter.emit_sdk(input: file2.path, output: out_dir2, tests: true, no_github_actions: true, no_installable_package: true)
    assert_includes out2, '# Summary String'
    assert File.exist?(File.join(out_dir2, 'lib', 'tests.rb'))
    file2.unlink
    FileUtils.rm_rf(out_dir2)

    openapi3 = {
      'openapi' => '3.0.0',
      'paths' => nil,
      'components' => {
        'examples' => {
          'E1' => {}
        }
      }
    }
    file3 = Tempfile.new(['openapi', '.json'])
    file3.write(openapi3.to_json)
    file3.close
    out_dir3 = Dir.mktmpdir
    out3 = Cdd::ClientSdk::Emitter.emit_sdk(input: file3.path, output: out_dir3, tests: true, no_github_actions: true, no_installable_package: true)
    assert_includes out3, 'class ClientSdk'
    assert File.exist?(File.join(out_dir3, 'lib', 'mocks.rb'))
    file3.unlink
    FileUtils.rm_rf(out_dir3)
  end

  def test_client_sdk_swagger_2_0_support
    spec = {
      'openapi' => '2.0',
      'host' => 'api.example.com',
      'basePath' => '/v2',
      'paths' => {
        '/test_form' => {
          'post' => {
            'operationId' => 'testForm',
            'consumes' => ['application/x-www-form-urlencoded'],
            'security' => [{ 'petstore_auth' => ['write:pets', 'read:pets'] }],
            'parameters' => [
              { 'name' => 'q1', 'in' => 'query', 'type' => 'string' },
              { 'name' => 'h1', 'in' => 'header', 'type' => 'string' },
              { 'name' => 'f1', 'in' => 'formData', 'type' => 'string' },
              { 'name' => 'b1', 'in' => 'body', 'schema' => { 'type' => 'object' } }
            ],
            'responses' => { '200' => { 'description' => 'OK' } }
          }
        },
        '/test_body_arr' => {
          'post' => {
            'operationId' => 'testBodyArr',
            'parameters' => [
              { 'name' => 'b2', 'in' => 'body', 'schema' => { 'type' => 'array' } }
            ]
          }
        },
        '/test_multipart' => {
          'post' => {
            'operationId' => 'testMultipart',
            'consumes' => ['multipart/form-data']
          }
        }
      }
    }

    file = Tempfile.new('openapi.json')
    file.write(spec.to_json)
    file.close

    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, 'lib'))
      FileUtils.mkdir_p(File.join(dir, 'spec'))
      Cdd::ClientSdk::Emitter.emit_sdk({ input: file.path, output: dir, tests: true })
      out = File.read(File.join(dir, 'lib', 'client.rb'))
      assert_match(%r{api\.example\.com/v2}, out)
      assert_match(/header_params\.keys\.each/, out)
      assert_match(/req\['api_key'\] = @api_key \|\| 'special-key'/, out)
      assert_match(%r{req.set_form.*/x-www-form-urlencoded'}, out)
      assert_match(%r{req.set_form.*/form-data'}, out)
    end
  ensure
    file.unlink
  end

  def test_client_sdk_openapi_3_0_form_and_array_bodies
    spec = {
      'openapi' => '3.0.0',
      'paths' => {
        '/test_o3_form' => {
          'post' => {
            'operationId' => 'testO3Form',
            'requestBody' => {
              'content' => {
                'application/x-www-form-urlencoded' => { 'schema' => { 'type' => 'object' } }
              }
            }
          }
        },
        '/test_o3_multipart' => {
          'post' => {
            'operationId' => 'testO3Multipart',
            'requestBody' => {
              'content' => {
                'multipart/form-data' => { 'schema' => { 'type' => 'object' } }
              }
            }
          }
        },
        '/test_o3_arr' => {
          'post' => {
            'operationId' => 'testO3Arr',
            'requestBody' => {
              'content' => {
                'application/json' => { 'schema' => { 'type' => 'array' } }
              }
            }
          }
        }
      }
    }
    file = Tempfile.new('openapi.json')
    file.write(spec.to_json)
    file.close

    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, 'lib'))
      FileUtils.mkdir_p(File.join(dir, 'spec'))
      Cdd::ClientSdk::Emitter.emit_sdk({ input: file.path, output: dir, tests: true })
      out = File.read(File.join(dir, 'spec', 'integration_spec.rb'))
      assert_match(/'body' => \[\{ 'id' => 1/, out)
    end
  ensure
    file.unlink
  end

  def test_client_sdk_xml_consumes_and_default_host
    spec = {
      'openapi' => '2.0',
      'basePath' => '/v3',
      'paths' => {
        '/test' => {
          'post' => {
            'operationId' => 'testXml',
            'consumes' => ['application/xml']
          }
        }
      }
    }
    file = Tempfile.new('openapi.json')
    file.write(spec.to_json)
    file.close

    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, 'lib'))
      FileUtils.mkdir_p(File.join(dir, 'spec'))
      Cdd::ClientSdk::Emitter.emit_sdk({ input: file.path, output: dir, tests: true })
      out = File.read(File.join(dir, 'lib', 'client.rb'))
      assert_match(%r{base_url = 'http://localhost/v3'}, out)
      assert_match(%r{'application/xml'}, out)
    end
  ensure
    file.unlink
  end

  def test_client_sdk_generated_rakefile_gemfile_and_integration_spec
    spec = {
      'openapi' => '3.0.0',
      'basePath' => '/v2',
      'components' => {
        'schemas' => {
          'Pet' => {
            'type' => 'object',
            'properties' => { 'id' => { 'type' => 'integer' }, 'name' => { 'type' => 'string' } }
          },
          'PetList' => {
            'type' => 'array',
            'items' => { '$ref' => '#/components/schemas/Pet' }
          },
          'ScalarString' => {
            'type' => 'string'
          }
        }
      },
      'paths' => {
        '/pets' => {
          'get' => {
            'operationId' => 'listPets',
            'responses' => {
              '200' => {
                'description' => 'OK',
                'content' => {
                  'application/json' => {
                    'schema' => { '$ref' => '#/components/schemas/PetList' }
                  }
                }
              },
              '500' => {
                'description' => 'Internal Error'
              }
            }
          },
          'post' => {
            'operationId' => 'createPet',
            'responses' => {
              '201' => {
                'description' => 'Created',
                'content' => {
                  'application/json' => {
                    'schema' => {
                      'type' => 'object',
                      'properties' => { 'id' => { 'type' => 'integer' } }
                    }
                  }
                }
              }
            }
          }
        },
        '/pets/accepted' => {
          'post' => {
            'operationId' => 'acceptPet',
            'responses' => {
              '202' => {
                'description' => 'Accepted',
                'schema' => { '$ref' => '#/components/schemas/ScalarString' }
              }
            }
          }
        },
        '/pets/unknown_ref' => {
          'get' => {
            'operationId' => 'unknownRefPet',
            'responses' => {
              '200' => {
                'description' => 'OK',
                'schema' => { '$ref' => '#/definitions/MissingModel' }
              }
            }
          }
        },
        '/pets/no_2xx' => {
          'get' => {
            'operationId' => 'no2xxPet',
            'responses' => {
              '404' => { 'description' => 'Not found' }
            }
          }
        }
      }
    }
    file = Tempfile.new(['openapi', '.json'])
    file.write(spec.to_json)
    file.close

    Dir.mktmpdir do |dir|
      Cdd::ClientSdk::Emitter.emit_sdk({ input: file.path, output: dir, tests: true })
      gemfile_path = File.join(dir, 'Gemfile')
      rakefile_path = File.join(dir, 'Rakefile')
      integration_spec_path = File.join(dir, 'spec', 'integration_spec.rb')

      assert File.exist?(gemfile_path)
      assert File.exist?(rakefile_path)
      assert File.exist?(integration_spec_path)

      gemfile_content = File.read(gemfile_path)
      assert_includes gemfile_content, "gem 'rake', '~> 13.0'"
      assert_includes gemfile_content, "gem 'rspec'"

      rakefile_content = File.read(rakefile_path)
      assert_includes rakefile_content, 'task :test'
      assert_includes rakefile_content, 'rspec'

      integration_content = File.read(integration_spec_path)
      assert RubyVM::InstructionSequence.compile(integration_content)
      assert_includes integration_content, "ENV['BASE_URL'] || ENV['API_URL'] || 'http://127.0.0.1:8080/v2'"
      assert_includes integration_content, 'TCPSocket.new(host, port).close'
      assert_includes integration_content, "if !server_listening && File.exist?('../../generated_server/server.rb')"
      assert_includes integration_content, "expect(client.last_response.code).not_to eq('500')"
      assert_includes integration_content, "validate_response_not_sabotaged!(response, 'array')"
      assert_includes integration_content, "validate_response_not_sabotaged!(response, 'object')"
      assert_includes integration_content, 'validate_response_not_sabotaged!(response, nil)'
      refute_includes integration_content, "skip 'Server is not available'"
    end
  ensure
    file.unlink
  end
end
