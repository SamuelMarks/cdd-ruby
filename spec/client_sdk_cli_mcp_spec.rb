# frozen_string_literal: true

require_relative 'spec_helper'
require_relative '../src/client_sdk_cli/emit'
require_relative '../src/client_sdk_cli/parse'
require_relative '../src/ir'
require 'open3'
require 'tmpdir'

class ClientSdkCliMcpTest < Minitest::Test
  def test_emits_and_executes_mcp_subcommand_end_to_end
    openapi = {
      'openapi' => '3.0.0',
      'info' => { 'title' => 'Test', 'version' => '1.0.0', 'description' => 'Sample Docs' },
      'paths' => {
        '/test' => {
          'get' => { 'operationId' => 'test_op' }
        }
      }
    }

    Dir.mktmpdir do |dir|
      spec_path = File.join(dir, 'spec.json')
      File.write(spec_path, openapi.to_json)
      code = Cdd::ClientSdkCli::Emitter.emit_sdk_cli({ input: spec_path, output: dir })

      assert_includes code, "when 'mcp'"
      assert_includes code, 'req = JSON.parse(line)'
      assert_includes code, "elsif req['method'] == 'tools/call'"

      cli_script = File.join(dir, 'sdk_cli.rb')
      req_lines = [
        { jsonrpc: '2.0', id: 1, method: 'initialize' },
        { jsonrpc: '2.0', id: 2, method: 'ping' },
        { jsonrpc: '2.0', id: 3, method: 'logging/setLevel', params: { level: 'info' } },
        { jsonrpc: '2.0', id: 4, method: 'resources/subscribe', params: { uri: 'mcp://api/docs' } },
        { jsonrpc: '2.0', id: 5, method: 'resources/unsubscribe', params: { uri: 'mcp://api/docs' } },
        { jsonrpc: '2.0', id: 6, method: 'resources/list' },
        { jsonrpc: '2.0', id: 7, method: 'resources/read', params: { uri: 'mcp://api/docs' } },
        { jsonrpc: '2.0', id: 8, method: 'resources/templates/list' },
        { jsonrpc: '2.0', id: 9, method: 'roots/list' },
        { jsonrpc: '2.0', id: 10, method: 'sampling/createMessage' },
        { jsonrpc: '2.0', id: 11, method: 'completion/complete' },
        { jsonrpc: '2.0', id: 12, method: 'prompts/list' },
        { jsonrpc: '2.0', id: 13, method: 'prompts/get', params: { name: 'api_help' } },
        { jsonrpc: '2.0', id: 14, method: 'tools/list' },
        { jsonrpc: '2.0', id: 15, method: 'tools/call', params: { name: 'test_op', arguments: { flag: true } } },
        { jsonrpc: '2.0', id: 16, method: 'unknown/method' }
      ].map(&:to_json).join("\n")
      requests = "#{req_lines}\n{bad_json\n"

      stdout_str, status = Open3.capture2('ruby', cli_script, 'mcp', stdin_data: requests)
      assert status.success?

      responses = stdout_str.lines.map { |line| JSON.parse(line) }
      by_id = responses.select { |r| r['id'] }.to_h { |r| [r['id'], r] }

      assert_equal '2024-11-05', by_id[1].dig('result', 'protocolVersion')
      assert_equal({}, by_id[2]['result'])
      assert_equal({}, by_id[3]['result'])
      assert_equal 'mcp://api/docs', by_id[6].dig('result', 'resources', 0, 'uri')
      assert_includes by_id[7].dig('result', 'contents', 0, 'text'), 'Sample Docs'
      assert_equal [], by_id[8].dig('result', 'resourceTemplates')
      assert_equal [], by_id[9].dig('result', 'roots')
      assert_equal 'sampled', by_id[10].dig('result', 'content', 'text')
      assert_equal 0, by_id[11].dig('result', 'completion', 'total')
      assert_equal 'api_help', by_id[12].dig('result', 'prompts', 0, 'name')
      assert_equal 'user', by_id[13].dig('result', 'messages', 0, 'role')
      assert_equal 'test_op', by_id[14].dig('result', 'tools', 0, 'name')
      assert_includes by_id[15].dig('result', 'content', 0, 'text'), 'Calling GET /test'
      assert_equal(-32_601, by_id[16].dig('error', 'code'))
      assert(responses.any? { |r| r.dig('error', 'code') == -32_700 })
    end
  end
end
