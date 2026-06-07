# frozen_string_literal: true

require_relative 'spec_helper'
require_relative '../src/client_sdk_cli/emit'
require_relative '../src/client_sdk_cli/parse'
require_relative '../src/ir'

describe Cdd::ClientSdkCli::Emitter do
  it 'emits mcp subcommand correctly' do
    openapi = {
      'openapi' => '3.0.0',
      'info' => { 'title' => 'Test', 'version' => '1.0.0' },
      'paths' => {
        '/test' => {
          'get' => { 'operationId' => 'test_op' }
        }
      }
    }

    Dir.mktmpdir do |dir|
      File.write("#{dir}/spec.json", openapi.to_json)
      code = Cdd::ClientSdkCli::Emitter.emit_sdk_cli({ input: "#{dir}/spec.json", output: dir })

      expect(code).to include "when 'mcp'"
      expect(code).to include 'req = JSON.parse(line)'
      expect(code).to include "elsif req['method'] == 'tools/call'"
      expect(code).to include "out = `ruby \#{__FILE__} \#{tool_name} \#{cmd_args}`"
      expect(code).to include "elsif req['method'] == 'resources/list'"
      expect(code).to include "elsif req['method'] == 'resources/read'"
      expect(code).to include "elsif req['method'] == 'roots/list'"
      expect(code).to include "elsif req['method'] == 'prompts/list'"
      expect(code).to include "elsif req['method'] == 'prompts/get'"
      expect(code).to include "elsif req['method'] == 'logging/setLevel'"
      expect(code).to include "elsif req['method'] == 'resources/subscribe'"
      expect(code).to include "elsif req['method'] == 'resources/unsubscribe'"
      expect(code).to include "elsif req['method'] == 'sampling/createMessage'"
      expect(code).to include "elsif req['method'] == 'completion/complete'"
      expect(code).to include "method: 'notifications/message'"
    end
  end
end
