# frozen_string_literal: true

require_relative 'spec_helper'

class DocsJsonEmitMissingTest < Minitest::Test
  def setup
    @filepath = 'dummy_openapi.json'
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
    File.delete(@filepath) if File.exist?(@filepath)
  end

  def test_docs_json_emit
    out = Cdd::DocsJson::Emitter.emit(@filepath)
    parsed = JSON.parse(out)

    endpoints = parsed['endpoints']
    assert endpoints.key?('/users')
    assert endpoints['/users'].key?('get')

    code = endpoints['/users']['get']
    assert_match(/require 'json'/, code)
    assert_match(/def main/, code)
    assert_match(/response = client\.listUsers\(\)/, code)
    assert_match(/end/, code)
  end

  def test_docs_json_emit_no_imports_no_wrapping
    out = Cdd::DocsJson::Emitter.emit(@filepath, no_imports: true, no_wrapping: true)
    parsed = JSON.parse(out)

    code = parsed['endpoints']['/users']['get']

    refute_match(/require/, code)
    refute_match(/def main/, code)
    refute_match(/end\n/, code)
    assert_match(/response = client\.listUsers\(\)/, code)
  end

  def test_docs_json_emit_from_url
    url = 'https://api.example.com/openapi.json'
    dummy_response = {
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
    Net::HTTP.define_singleton_method(:get) { |_uri| dummy_response }
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
end
