# frozen_string_literal: true

require_relative 'spec_helper'
require 'tmpdir'
require 'stringio'

class ClientSdkCliServerArazzoTest < Minitest::Test
  def sample_arazzo
    {
      'arazzo' => '1.1.0',
      'info' => { 'title' => 'Workflows', 'version' => '1.1.0' },
      'sourceDescriptions' => [{ 'name' => 'petstore', 'url' => './petstore.json', 'type' => 'openapi' }],
      'workflows' => [
        {
          'workflowId' => 'checkout_flow',
          'summary' => 'Checkout workflow',
          'steps' => [
            { 'stepId' => 'step_one', 'operationId' => 'get_hello' }
          ]
        },
        {
          'workflowId' => 'fallback_flow',
          'steps' => [
            { 'stepId' => 'step_two', 'operationId' => 'get_hello' }
          ]
        }
      ]
    }
  end

  def sample_openapi
    {
      'openapi' => '3.2.0',
      'info' => { 'title' => 'Store API', 'version' => '1.0.0' },
      'paths' => {
        '/hello' => {
          'get' => {
            'operationId' => 'get_hello',
            'responses' => { '200' => { 'description' => 'OK' } }
          }
        }
      }
    }
  end

  def test_client_sdk_arazzo_generation_and_parsing
    Dir.mktmpdir do |dir|
      arazzo_path = File.join(dir, 'arazzo.json')
      oas_path = File.join(dir, 'oas.json')
      File.write(arazzo_path, JSON.pretty_generate(sample_arazzo))
      File.write(oas_path, JSON.pretty_generate(sample_openapi))

      sdk_out = File.join(dir, 'sdk_from_arazzo')
      code = Cdd::ClientSdk::Emitter.emit_sdk(input: arazzo_path, output: sdk_out, tests: true)
      assert_includes code, 'ClientSdkWorkflows = WorkflowsOrchestrator'
      assert File.exist?(File.join(sdk_out, 'lib', 'workflows.rb'))

      combo_out = File.join(dir, 'sdk_combo')
      combo_code = Cdd::ClientSdk::Emitter.emit_sdk(input: oas_path, arazzo: arazzo_path, output: combo_out)
      assert_includes combo_code, 'def workflows'
      assert_includes combo_code, 'def checkout_flow'

      sandbox = Module.new
      sandbox.module_eval(combo_code.sub("require_relative 'models'", ''))
      client_cls = sandbox.const_get(:ClientSdk)
      client_inst = client_cls.new('http://localhost:8080')
      client_inst.define_singleton_method(:get_hello) { |*_args| { 'ok' => true } }
      assert_kind_of sandbox.const_get(:WorkflowsOrchestrator), client_inst.workflows
      assert_equal({ 'step_one' => { response: { 'ok' => true }, outputs: {} } },
                   client_inst.mcp.execute_tool('checkout_flow', {}))
      assert_equal({ 'ok' => true }, client_inst.mcp.execute_tool('get_hello', {}))

      ir = Cdd::IR.new
      Cdd::ClientSdk::Parser.parse(Ripper.lex(combo_code), ir)
      assert_includes ir.workflows, 'checkout_flow'
      assert_equal 'get_hello', ir.openapi_spec.dig('paths', '/hello', 'get', 'operationId')
    end
  end

  def test_client_sdk_cli_arazzo_generation_and_parsing
    Dir.mktmpdir do |dir|
      arazzo_path = File.join(dir, 'arazzo.json')
      File.write(arazzo_path, JSON.pretty_generate(sample_arazzo))
      cli_out = File.join(dir, 'cli_out')

      cli_code = Cdd::ClientSdkCli::Emitter.emit_sdk_cli(input: arazzo_path, output: cli_out)
      assert_includes cli_code, "when 'workflow'"
      assert_includes cli_code, "when 'checkout_flow'"
      assert_includes cli_code, 'workflow list | run <workflowId>'

      ir = Cdd::IR.new
      Cdd::ClientSdkCli::Parser.parse(Ripper.lex(cli_code), ir)
      assert_equal %w[checkout_flow fallback_flow], ir.workflows
      assert_equal '', Cdd::ClientSdk::Emitter.emit_workflows_code({ 'workflows' => [] })
      assert_equal '', Cdd::ClientSdkCli::Emitter.emit_help_workflows([])
      assert_includes Cdd::ClientSdkCli::Emitter.emit_command_branches({}, { 'workflows' => [] }), 'Unknown command'
    end
  end

  def test_server_and_tests_arazzo_generation_and_parsing
    Dir.mktmpdir do |dir|
      arazzo_path = File.join(dir, 'arazzo.json')
      File.write(arazzo_path, JSON.pretty_generate(sample_arazzo))
      srv_out = File.join(dir, 'srv_out')

      srv_code = Cdd::ServerGen::Emitter.emit_server(input: arazzo_path, output: srv_out, tests: true)
      assert_includes srv_code, "Dir.glob(File.join(__dir__, 'workflows', '*.rb'))"
      assert File.exist?(File.join(srv_out, 'workflows', 'arazzo_engine.rb'))
      assert File.exist?(File.join(srv_out, 'routes', 'arazzo_routes.rb'))
      assert File.exist?(File.join(srv_out, 'tests', 'arazzo_workflows_test.rb'))

      test_code = File.read(File.join(srv_out, 'tests', 'arazzo_workflows_test.rb'))
      assert_includes test_code, 'class ArazzoWorkflowsTest < Minitest::Test'
      assert_includes test_code, 'def test_workflow_checkout_flow'

      ir = Cdd::IR.new
      Cdd::Tests::Parser.parse(Ripper.lex(test_code), ir)
      assert_includes ir.workflows, 'checkout_flow'

      srv_ir = Cdd::IR.new
      engine_code = File.read(File.join(srv_out, 'workflows', 'arazzo_engine.rb'))
      Cdd::ServerGen::Parser.parse(Ripper.lex(engine_code), srv_ir)
      assert_includes srv_ir.workflows, 'checkout_flow'
    end
  end

  def test_cli_rpc_sync_and_docs_json_arazzo_commands
    Dir.mktmpdir do |dir|
      arazzo_path = File.join(dir, 'arazzo.json')
      wf_rb_path = File.join(dir, 'workflows.rb')
      out_arazzo = File.join(dir, 'out_arazzo.json')
      File.write(arazzo_path, JSON.pretty_generate(sample_arazzo))
      File.write(wf_rb_path, Cdd::Emitter.emit_from_arazzo(arazzo_path))

      cfg = Cdd::Config.new(subcommand: 'to_sdk', input: arazzo_path, output: File.join(dir, 'sdk1'), arazzo: arazzo_path)
      assert_equal arazzo_path, cfg[:arazzo]
      assert_includes cfg.to_a, '--arazzo'

      old_stdout = $stdout
      $stdout = StringIO.new
      begin
        assert_equal 0, Cdd::CLI.run(['from_arazzo', '--help'])
        assert_equal 0, Cdd::CLI.run(['to_arazzo', '--help'])
        assert_equal 1, Cdd::CLI.run(['to_arazzo'])
        assert_equal 0, Cdd::CLI.generate_from_arazzo(
          Cdd::Config.new(subcommand: 'to_sdk', input: arazzo_path, output: File.join(dir, 'sdk2'))
        )
        assert_equal 0, Cdd::CLI.generate_to_arazzo(
          Cdd::Config.new(input: wf_rb_path, output: out_arazzo)
        )
        assert_equal 0, Cdd::CLI.run(['to_arazzo', '-i', dir, '-o', out_arazzo])
      ensure
        $stdout = old_stdout
      end
      assert File.exist?(out_arazzo)

      rpc_arazzo = JSON.parse(Cdd::Server.handle_rpc('to_arazzo', { 'input' => wf_rb_path }))
      assert_equal '1.1.0', rpc_arazzo['arazzo']
      assert_includes Cdd::Server.handle_rpc('from_arazzo_to_sdk', { 'input' => arazzo_path }), 'ClientSdk'
      assert_includes Cdd::Server.handle_rpc('from_arazzo_to_sdk_cli', { 'input' => arazzo_path }), 'sdk_cli'
      assert_includes Cdd::Server.handle_rpc('from_arazzo_to_server',
                                             { 'input' => arazzo_path, 'output' => File.join(dir, 'rpc_srv') }),
                      'sinatra'

      mcp_resp1 = Cdd::CLI.handle_mcp_tool_call(
        { 'id' => 1, 'params' => { 'name' => 'inspect_schema', 'arguments' => { 'filepath' => arazzo_path } } },
        { jsonrpc: '2.0', id: 1, result: {} }
      )
      assert_includes mcp_resp1[:result][:content][0][:text], 'Workflows: checkout_flow, fallback_flow'

      mcp_resp2 = Cdd::CLI.handle_mcp_tool_call(
        { 'id' => 2,
          'params' => { 'name' => 'generate_from_arazzo',
                        'arguments' => { 'subcommand' => 'to_sdk', 'input' => arazzo_path,
                                         'output' => File.join(dir, 'mcp_sdk') } } },
        { jsonrpc: '2.0', id: 2, result: {} }
      )
      assert_equal 'Generated successfully', mcp_resp2[:result][:content][0][:text]

      mcp_resp3 = Cdd::CLI.handle_mcp_tool_call(
        { 'id' => 3,
          'params' => { 'name' => 'generate_to_arazzo',
                        'arguments' => { 'input' => wf_rb_path, 'output' => File.join(dir, 'mcp_out.json') } } },
        { jsonrpc: '2.0', id: 3, result: {} }
      )
      assert_equal 'Generated successfully', mcp_resp3[:result][:content][0][:text]

      mcp_resp4 = Cdd::CLI.handle_mcp_tool_call(
        { 'id' => 4,
          'params' => { 'name' => 'generate_to_arazzo',
                        'arguments' => { 'input' => wf_rb_path } } },
        { jsonrpc: '2.0', id: 4, result: {} }
      )
      FileUtils.rm_f('arazzo.json')
      assert_equal 'Generated successfully', mcp_resp4[:result][:content][0][:text]

      sync_spec_path = File.join(dir, 'sync_arazzo.json')
      File.write(sync_spec_path, JSON.generate({ 'arazzo' => '1.1.0', 'workflows' => [] }))
      Cdd::Sync.sync(sync_spec_path, 'workflow')
      synced = JSON.parse(File.read(sync_spec_path))
      assert_equal 'checkout_flow', synced['workflows'][0]['workflowId']

      docs_json_str = Cdd::DocsJson::Emitter.emit(arazzo_path)
      docs_hash = JSON.parse(docs_json_str)
      assert_includes docs_hash['workflows']['checkout_flow']['snippet'], 'client.checkout_flow()'

      docs_ir = Cdd::IR.new
      Cdd::DocsJson::Parser.parse(docs_json_str, docs_ir)
      assert_includes docs_ir.workflows, 'checkout_flow'

      wf_only_ir = Cdd::IR.new
      Cdd::DocsJson::Parser.parse({ 'workflows' => { 'wf_only' => 'client.wf_only()' } }, wf_only_ir)
      assert_includes wf_only_ir.workflows, 'wf_only'
    end
  end
end
