# frozen_string_literal: true

require_relative 'spec_helper'
require 'open3'
require 'json'
require 'fileutils'
require 'tmpdir'

class CliMcpInspectSchemaTest < Minitest::Test
  def test_inspect_schema
    Dir.mktmpdir do |dir|
      schema_path = File.join(dir, 'sample_schema.json')
      File.write(schema_path, '{"info":{"title":"Test API","version":"1.0.0"},"paths":{"/test":{}},"components":{"schemas":{"User":{}}}}')

      Open3.popen3('ruby -Isrc bin/cdd-ruby mcp') do |stdin, stdout, _stderr, _wait_thr|
        stdin.puts(%({"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"inspect_schema","arguments":{"filepath":"#{schema_path}"}}}))
        stdin.puts '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"inspect_schema","arguments":{"filepath":"does_not_exist.json"}}}'
        stdin.close

        output_lines = stdout.read.lines.map(&:chomp)

        resp1 = JSON.parse(output_lines[0])
        assert_equal 1, resp1['id']
        assert_includes resp1['result']['content'][0]['text'], 'Schema: Test API 1.0.0'
        assert_includes resp1['result']['content'][0]['text'], 'Paths: /test'
        assert_includes resp1['result']['content'][0]['text'], 'Components: User'

        notif = JSON.parse(output_lines[1])
        assert_equal 'notifications/message', notif['method']

        resp2 = JSON.parse(output_lines[2])
        assert_equal 2, resp2['id']
        assert resp2['result']['isError']
        assert_includes resp2['result']['content'][0]['text'], 'No such file or directory'
      end
    end
  end
end
