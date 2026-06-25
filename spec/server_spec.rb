# frozen_string_literal: true

require_relative 'spec_helper'
require_relative '../src/server'

class ServerTest < Minitest::Test
  def setup
    File.write('dummy_server_test.rb', "# @route GET /hello\nclass User\nend\n")
    File.write('dummy_server_test.json', '{"openapi":"3.2.0","info":{"title":"API","version":"1.0.0"},"paths":{}}')
  end

  def teardown
    FileUtils.rm_f('dummy_server_test.rb')
    FileUtils.rm_f('dummy_server_test.json')
  end

  def test_handle_rpc
    assert_equal '0.0.3', Cdd::Server.handle_rpc('version', {})

    res = Cdd::Server.handle_rpc('to_openapi', { 'input' => 'dummy_server_test.rb' })
    assert_match(/openapi/, res)

    res2 = Cdd::Server.handle_rpc('to_docs_json', { 'input' => 'dummy_server_test.json' })
    assert_match(/\{\}/, res2)

    Cdd::Server.handle_rpc('from_openapi_to_sdk_cli', { 'input' => 'dummy_server_test.json', 'output' => 'tmp_out_cli' })
    assert File.exist?('tmp_out_cli/sdk_cli.rb')
    FileUtils.rm_rf('tmp_out_cli')

    Cdd::Server.handle_rpc('from_openapi_to_sdk', { 'input' => 'dummy_server_test.json', 'output' => 'tmp_out_sdk' })
    assert File.exist?('tmp_out_sdk/lib/client.rb')
    FileUtils.rm_rf('tmp_out_sdk')

    Cdd::Server.handle_rpc('from_openapi_to_server', { 'input' => 'dummy_server_test.json', 'output' => 'tmp_out_server' })
    assert File.exist?('tmp_out_server/server.rb')
    FileUtils.rm_rf('tmp_out_server')

    assert_raises(StandardError) do
      Cdd::Server.handle_rpc('unknown_method', {})
    end
  end

  def test_server_start
    require 'net/http'
    require 'uri'

    server_thread = Thread.new do
      Cdd::Server.start('127.0.0.1', '12345')
    end

    sleep 0.5 # wait for server to start

    uri = URI.parse('http://127.0.0.1:12345/')
    http = Net::HTTP.new(uri.host, uri.port)

    # Test valid JSON-RPC
    req = Net::HTTP::Post.new(uri.request_uri, 'Content-Type' => 'application/json')
    req.body = { jsonrpc: '2.0', method: 'version', id: 1 }.to_json
    res = http.request(req)
    assert_equal '200', res.code
    assert_equal '0.0.3', JSON.parse(res.body)['result']

    # Test invalid JSON-RPC (missing jsonrpc version)
    req.body = { method: 'version', id: 1 }.to_json
    res2 = http.request(req)
    assert_equal '400', res2.code

    # Test error in JSON-RPC
    req.body = { jsonrpc: '2.0', method: 'unknown', id: 1 }.to_json
    res3 = http.request(req)
    assert_equal '500', res3.code

    # Test GET method
    req_get = Net::HTTP::Get.new(uri.request_uri)
    res_get = http.request(req_get)
    assert_equal '405', res_get.code

    Process.kill('INT', Process.pid)
    server_thread.join
  end
end
