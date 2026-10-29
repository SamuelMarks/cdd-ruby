# frozen_string_literal: true

require_relative 'spec_helper'
require 'tempfile'
require 'tmpdir'

class DocsJsonTest < Minitest::Test
  def setup
    @tmp_dir = Dir.mktmpdir
    @filepath = File.join(@tmp_dir, 'openapi.json')
    File.write(@filepath, {
      'openapi' => '3.2.0',
      'paths' => {
        '/users' => {
          'get' => {
            'operationId' => 'listUsers'
          }
        }
      }
    }.to_json)
  end

  def teardown
    FileUtils.rm_rf(@tmp_dir)
  end

  def test_docs_json_emit
    out = Cdd::DocsJson::Emitter.emit(@filepath)
    parsed = JSON.parse(out)

    assert_equal "require 'json'\nrequire 'my_api_client'", parsed['imports']
    assert_equal "def main\n  client = MyApiClient.new('https://api.example.com')", parsed['wrapper_start']
    assert_equal "end\n\nmain if __FILE__ == $0", parsed['wrapper_end']

    endpoints = parsed['endpoints']
    assert endpoints.key?('/users')
    assert endpoints['/users'].key?('get')

    entry = endpoints['/users']['get']
    assert_equal "require 'json'\nrequire 'my_api_client'", entry['imports']
    assert_equal "def main\n  client = MyApiClient.new('https://api.example.com')", entry['wrapper_start']
    assert_equal "  response = client.listUsers()\n  puts response.inspect", entry['snippet']
    assert_equal "end\n\nmain if __FILE__ == $0", entry['wrapper_end']
    assert_match(/require 'json'/, entry['code'])
    assert_match(/def main/, entry['code'])
    assert_match(/response = client\.listUsers\(\)/, entry['code'])
    assert_match(/end/, entry['code'])
  end

  def test_docs_json_emit_no_imports_no_wrapping
    out = Cdd::DocsJson::Emitter.emit(@filepath, no_imports: true, no_wrapping: true)
    parsed = JSON.parse(out)

    assert_nil parsed['imports']
    assert_nil parsed['wrapper_start']
    assert_nil parsed['wrapper_end']

    entry = parsed['endpoints']['/users']['get']
    assert_nil entry['imports']
    assert_nil entry['wrapper_start']
    assert_nil entry['wrapper_end']
    assert_equal "response = client.listUsers()\nputs response.inspect", entry['snippet']
    assert_equal "response = client.listUsers()\nputs response.inspect", entry['code']
  end

  def test_docs_json_emit_params_webhooks_and_workflows
    spec = {
      'openapi' => '3.2.0',
      'paths' => {
        '/users/{id}' => {
          'put' => {
            'operationId' => 'updateUser',
            'parameters' => [
              { 'name' => 'id', 'in' => 'path', 'required' => true, 'schema' => { 'type' => 'integer' } },
              { 'name' => 'status', 'in' => 'query', 'schema' => { 'type' => 'string' } }
            ],
            'requestBody' => {
              'required' => true,
              'content' => {
                'application/json' => {
                  'schema' => {
                    'type' => 'object',
                    'properties' => { 'name' => { 'type' => 'string' } }
                  }
                }
              }
            }
          }
        }
      },
      'webhooks' => {
        'userUpdated' => {
          'post' => {
            'operationId' => 'onUserUpdated',
            'requestBody' => {
              'content' => {
                'application/json' => {
                  'schema' => { '$ref' => '#/components/schemas/User' }
                }
              }
            }
          }
        }
      },
      'workflows' => [
        { 'workflowId' => 'syncUsers' }
      ]
    }
    spec_path = File.join(@tmp_dir, 'rich_openapi.json')
    File.write(spec_path, spec.to_json)

    out = Cdd::DocsJson::Emitter.emit(spec_path)
    parsed = JSON.parse(out)

    put_entry = parsed.dig('endpoints', '/users/{id}', 'put')
    assert_includes put_entry['snippet'], "client.updateUser(id: 1, status: 'available', body: { name: 'test' })"

    wh_entry = parsed.dig('webhooks', 'userUpdated', 'post')
    assert_includes wh_entry['snippet'], 'client.onUserUpdated(body: {'

    wf_entry = parsed.dig('workflows', 'syncUsers')
    assert_includes wf_entry['snippet'], 'client.syncUsers()'

    ir = Cdd::IR.new
    Cdd::DocsJson::Parser.parse(out, ir)
    assert_equal 'updateUser', ir.openapi_spec.dig('paths', '/users/{id}', 'put', 'operationId')
    assert_equal 'onUserUpdated', ir.openapi_spec.dig('webhooks', 'userUpdated', 'post', 'operationId')
    assert_includes ir.workflows, 'syncUsers'
  end

  def test_docs_json_emit_from_url
    url = 'https://api.example.com/openapi.json'
    remote_response = {
      'openapi' => '3.2.0',
      'paths' => {
        '/users' => {
          'get' => {
            'operationId' => 'listUsers'
          }
        }
      }
    }.to_json

    original_get = Net::HTTP.method(:get)
    Net::HTTP.define_singleton_method(:get) { |_uri| remote_response }
    begin
      out = Cdd::DocsJson::Emitter.emit(url)
      parsed = JSON.parse(out)

      endpoints = parsed['endpoints']
      assert endpoints.key?('/users')
      assert endpoints['/users'].key?('get')
    ensure
      Net::HTTP.define_singleton_method(:get, &original_get)
    end
  end

  def test_docs_json_emit_no_net_http
    original_net = Object.send(:remove_const, :Net)
    begin
      assert_raises(Cdd::UnsupportedEnvironmentError) do
        Cdd::DocsJson::Emitter.emit('http://example.com/api.json')
      end
    ensure
      Object.const_set(:Net, original_net)
    end
  end

  def test_docs_json_emit_summary_and_non_verb_keys
    openapi = {
      'openapi' => '3.0.0',
      'paths' => {
        '/test' => {
          'get' => {
            'operationId' => 'op',
            'summary' => 's'
          }
        }
      }
    }

    file = Tempfile.new(['openapi', '.json'])
    file.write(openapi.to_json)
    file.close

    out = Cdd::DocsJson::Emitter.emit(file.path, no_imports: true, no_wrapping: true)
    assert_match(/response = client\.op/, out)
    refute_match(/require 'json'/, out)
    file.unlink

    openapi2 = {
      'openapi' => '3.0.0',
      'paths' => {
        '/test' => {
          'x-test' => {},
          'parameters' => [],
          'post' => {}
        },
        '/empty' => {}
      }
    }

    file2 = Tempfile.new(['openapi', '.json'])
    file2.write(openapi2.to_json)
    file2.close

    out2 = Cdd::DocsJson::Emitter.emit(file2.path)
    assert_match(/post_test/, out2)
    file2.unlink
  end

  def test_docs_json_parse_from_hash_and_tokens
    ir = Cdd::IR.new
    payload = {
      'endpoints' => {
        '/pets' => {
          'GET' => "response = client.list_pets()
puts response.inspect",
          'POST' => 'puts "no client call"'
        },
        '/invalid' => 'not_a_hash'
      }
    }

    Cdd::DocsJson::Parser.parse(payload, ir)
    assert_equal 'list_pets', ir.openapi_spec.dig('paths', '/pets', 'get', 'operationId')
    assert_equal 'OK', ir.openapi_spec.dig('paths', '/pets', 'post', 'responses', '200', 'description')
    assert_nil ir.openapi_spec.dig('paths', '/pets', 'post', 'operationId')
    assert_nil ir.openapi_spec.dig('paths', '/invalid')

    ir2 = Cdd::IR.new
    json_str = JSON.generate(payload)
    tokens = Ripper.lex(json_str)
    Cdd::DocsJson::Parser.parse(tokens, ir2)
    assert_equal 'list_pets', ir2.openapi_spec.dig('paths', '/pets', 'get', 'operationId')

    ir3 = Cdd::IR.new
    Cdd::DocsJson::Parser.parse(json_str, ir3)
    assert_equal 'list_pets', ir3.openapi_spec.dig('paths', '/pets', 'get', 'operationId')

    ir4 = Cdd::IR.new
    Cdd::DocsJson::Parser.parse(['raw_fragment'], ir4)
    assert_empty ir4.openapi_spec['paths']

    assert_nil Cdd::DocsJson::Parser.extract_payload(12_345)
    assert_nil Cdd::DocsJson::Parser.extract_payload('   ')
    assert_nil Cdd::DocsJson::Parser.extract_payload('{invalid json')
  end
end
