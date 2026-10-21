# frozen_string_literal: true

require_relative 'spec_helper'
require_relative '../src/server'
require 'tmpdir'

class ServerTest < Minitest::Test
  def setup
    @tmp_dir = Dir.mktmpdir
    @rb_path = File.join(@tmp_dir, 'server_sample.rb')
    @json_path = File.join(@tmp_dir, 'server_sample.json')
    File.write(@rb_path, "# @route GET /hello
class User
end
")
    File.write(@json_path, '{"openapi":"3.2.0","info":{"title":"API","version":"1.0.0"},"paths":{}}')
  end

  def teardown
    FileUtils.rm_rf(@tmp_dir)
  end

  def test_handle_rpc
    assert_equal '0.0.4', Cdd::Server.handle_rpc('version', {})

    res = Cdd::Server.handle_rpc('to_openapi', { 'input' => @rb_path })
    assert_match(/openapi/, res)

    res2 = Cdd::Server.handle_rpc('to_docs_json', { 'input' => @json_path })
    assert_match(/\{\}/, res2)

    out_cli = File.join(@tmp_dir, 'cli')
    Cdd::Server.handle_rpc('from_openapi_to_sdk_cli', { 'input' => @json_path, 'output' => out_cli })
    assert File.exist?(File.join(out_cli, 'sdk_cli.rb'))

    out_sdk = File.join(@tmp_dir, 'sdk')
    Cdd::Server.handle_rpc('from_openapi_to_sdk', { 'input' => @json_path, 'output' => out_sdk })
    assert File.exist?(File.join(out_sdk, 'lib', 'client.rb'))

    out_server = File.join(@tmp_dir, 'server')
    Cdd::Server.handle_rpc('from_openapi_to_server', { 'input' => @json_path, 'output' => out_server })
    assert File.exist?(File.join(out_server, 'server.rb'))

    assert_raises(StandardError) do
      Cdd::Server.handle_rpc('unknown_method', {})
    end
  end

  def test_server_start
    require 'net/http'
    require 'uri'
    require 'stringio'

    Cdd::Server.instance_variable_set(:@current_server, nil)
    Cdd::Server.shutdown
    server_thread = Thread.new do
      old_stdout = $stdout
      $stdout = StringIO.new
      begin
        Cdd::Server.start('127.0.0.1', 0)
      ensure
        $stdout = old_stdout
      end
    end

    sleep 0.05 until Cdd::Server.current_server && Cdd::Server.current_server.status == :Running
    port = Cdd::Server.current_server.config[:Port]

    uri = URI.parse("http://127.0.0.1:#{port}/")
    http = Net::HTTP.new(uri.host, uri.port)

    # Test valid JSON-RPC
    req = Net::HTTP::Post.new(uri.request_uri, 'Content-Type' => 'application/json')
    req.body = { jsonrpc: '2.0', method: 'version', id: 1 }.to_json
    res = http.request(req)
    assert_equal '200', res.code
    assert_equal '0.0.4', JSON.parse(res.body)['result']

    # Test invalid JSON-RPC (missing jsonrpc version)
    req.body = { method: 'version', id: 1 }.to_json
    res2 = http.request(req)
    assert_equal '400', res2.code

    # Test error in JSON-RPC (unknown method -> Cdd::RpcError)
    req.body = { jsonrpc: '2.0', method: 'unknown', id: 1 }.to_json
    res3 = http.request(req)
    assert_equal '500', res3.code
    assert_equal(-32_601, JSON.parse(res3.body)['code'])

    # Test malformed JSON body (-> StandardError / JSON::ParserError)
    req.body = '{invalid_json'
    res_malformed = http.request(req)
    assert_equal '500', res_malformed.code
    assert_equal(-32_700, JSON.parse(res_malformed.body)['code'])

    # Test GET method
    req_get = Net::HTTP::Get.new(uri.request_uri)
    res_get = http.request(req_get)
    assert_equal '405', res_get.code

    Cdd::Server.shutdown
    server_thread.join
  end
end
