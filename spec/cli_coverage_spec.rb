# frozen_string_literal: true

require_relative 'spec_helper'
require_relative '../src/cli'
require 'stringio'

class CliCoverageTest < Minitest::Test
  def setup
    File.write('dummy_cli_test.rb', "# @route GET /hello\nclass User\nend\n")
    File.write('dummy_cli_test.json', '{"openapi":"3.2.0","info":{"title":"API","version":"1.0.0"},"paths":{}}')
    FileUtils.mkdir_p('dummy_cli_dir')
    File.write('dummy_cli_dir/dummy.rb', "class A\nend\n")
  end

  def teardown
    FileUtils.rm_f('dummy_cli_test.rb')
    FileUtils.rm_f('dummy_cli_test.json')
    FileUtils.rm_f('spec.json')
    FileUtils.rm_f('docs.json')
    FileUtils.rm_rf('dummy_cli_dir')
    FileUtils.rm_rf('tmp_out_cli_cov')
  end

  def capture_stdout
    old_stdout = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = old_stdout
  end

  def test_cli_options_parsing
    capture_stdout do
      CDD::CLI.run(['to_openapi', '-i', 'dummy_cli_test.rb', '-o', 'tmp_out_cli_cov/out.json', '--no-imports', '--no-wrapping', '--no-github-actions', '--no-installable-package', '--tests', '--mcp', '-p', '1234', '-l', '127.0.0.1', '--input-dir', 'dummy_cli_dir', '--with-ephemeral', '--with-seed'])
    end
    assert File.exist?('tmp_out_cli_cov/out.json')
  end

  def test_cli_to_openapi_dir
    capture_stdout do
      CDD::CLI.run(['to_openapi', '-i', 'dummy_cli_dir', '-o', 'tmp_out_cli_cov/out2.json'])
    end
    assert File.exist?('tmp_out_cli_cov/out2.json')
  end

  def test_cli_to_openapi_default_out
    capture_stdout do
      CDD::CLI.run(['to_openapi', '-i', 'dummy_cli_test.rb'])
    end
    assert File.exist?('spec.json')
  end

  def test_cli_to_openapi_stdout
    out = capture_stdout do
      CDD::CLI.run(['to_openapi', '-i', 'dummy_cli_test.rb', '-o', '-'])
    end
    assert_match(/openapi/, out)
  end

  def test_cli_sync_options
    capture_stdout do
      CDD::CLI.run(['sync', '-i', 'dummy_cli_test.json', '--truth', 'class'])
    end
  end

  def test_cli_to_docs_json_options
    capture_stdout do
      CDD::CLI.run(['to_docs_json', '-i', 'dummy_cli_test.json', '-o', 'tmp_out_cli_cov/docs.json'])
    end
    assert File.exist?('tmp_out_cli_cov/docs.json')
  end

  def test_cli_to_docs_json_default_out
    capture_stdout do
      CDD::CLI.run(['to_docs_json', '-i', 'dummy_cli_test.json'])
    end
    assert File.exist?('docs.json')
  end

  def test_cli_to_docs_json_stdout
    out = capture_stdout do
      CDD::CLI.run(['to_docs_json', '-i', 'dummy_cli_test.json', '-o', '-'])
    end
    assert_match(/\{\}/, out)
  end

  def test_cli_from_openapi_options
    capture_stdout do
      CDD::CLI.run(['from_openapi', 'to_sdk_cli', '-i', 'dummy_cli_test.json', '-o', 'tmp_out_cli_cov', '--no-github-actions', '--no-installable-package', '--tests', '--mcp', '--with-ephemeral', '--with-seed'])
      # Fix the missing '-i' for to_sdk
      CDD::CLI.run(['from_openapi', 'to_sdk', '-i', 'dummy_cli_test.json', '--input-dir', 'dummy_cli_dir', '-o', 'tmp_out_cli_cov/sdk'])
      CDD::CLI.run(['from_openapi', 'to_server', '-i', 'dummy_cli_test.json', '-o', 'tmp_out_cli_cov/server'])
    end
  end

  def test_cli_serve_json_rpc_options
    original_start = Cdd::Server.method(:start)
    begin
      Cdd::Server.singleton_class.define_method(:start) { |_l, _p| nil }
      CDD::CLI.run(['serve_json_rpc', '-p', '4321', '-l', '127.0.0.1'])
    ensure
      Cdd::Server.singleton_class.define_method(:start, original_start)
    end
  end

  def test_cli_mcp
    old_stdin = $stdin
    req1 = { jsonrpc: '2.0', id: 1, method: 'initialize' }.to_json
    req2 = { jsonrpc: '2.0', id: 2, method: 'tools/list' }.to_json
    req3 = { jsonrpc: '2.0', id: 3, method: 'tools/call', params: { name: 'inspect_schema', arguments: { filepath: 'dummy_cli_test.json' } } }.to_json
    req4 = { jsonrpc: '2.0', id: 4, method: 'tools/call', params: { name: 'inspect_schema', arguments: { filepath: 'not_exist.json' } } }.to_json
    req5 = { jsonrpc: '2.0', id: 5, method: 'tools/call', params: { name: 'generate_from_openapi', arguments: { subcommand: 'to_sdk_cli', input: 'dummy_cli_test.json', output: 'tmp_out_cli_cov/mcp1' } } }.to_json
    req6 = { jsonrpc: '2.0', id: 6, method: 'tools/call', params: { name: 'generate_to_openapi', arguments: { input: 'dummy_cli_test.rb', output: 'tmp_out_cli_cov/mcp2.json' } } }.to_json
    req7 = { jsonrpc: '2.0', id: 7, method: 'prompts/list' }.to_json
    req8 = { jsonrpc: '2.0', id: 8, method: 'prompts/get', params: { name: 'generate_docs', arguments: { filepath: 'dummy.rb' } } }.to_json
    req9 = { jsonrpc: '2.0', id: 9, method: 'resources/list' }.to_json
    req10 = { jsonrpc: '2.0', id: 10, method: 'resources/read', params: { uri: 'mcp://cdd/docs' } }.to_json
    req11 = { jsonrpc: '2.0', id: 11, method: 'resources/templates/list' }.to_json
    req12 = { jsonrpc: '2.0', id: 12, method: 'roots/list' }.to_json
    req13 = { jsonrpc: '2.0', id: 13, method: 'ping' }.to_json
    req14 = { jsonrpc: '2.0', id: 14, method: 'sampling/createMessage' }.to_json
    req15 = { jsonrpc: '2.0', id: 15, method: 'completion/complete' }.to_json
    req16 = { jsonrpc: '2.0', id: 16, method: 'unknown' }.to_json
    req17 = { method: 'notifications/cancelled' }.to_json
    req18 = 'invalid json'
    req19 = { jsonrpc: '2.0', id: 19, method: 'tools/call', params: { name: 'unknown_tool' } }.to_json

    inputs = "#{[req1, req2, req3, req4, req5, req6, req7, req8, req9, req10, req11, req12, req13, req14, req15, req16, req17, req18, req19].join("\n")}\n"

    $stdin = StringIO.new(inputs)

    capture_stdout do
      CDD::CLI.run(['mcp'])
    end
  ensure
    $stdin = old_stdin
  end
end
