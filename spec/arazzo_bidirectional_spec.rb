# frozen_string_literal: true

require_relative 'spec_helper'
require 'tmpdir'

class ArazzoBidirectionalTest < Minitest::Test
  def full_arazzo_spec
    {
      'arazzo' => '1.1.0',
      '$self' => 'https://example.com/arazzo.json',
      'x-root' => 'v1',
      'info' => {
        'title' => 'Petstore Orchestration',
        'summary' => 'Petstore E2E Flows',
        'description' => 'Chained petstore workflows',
        'version' => '1.1.0',
        'x-info' => 1
      },
      'sourceDescriptions' => [
        { 'name' => 'petstore', 'url' => './petstore.json', 'type' => 'openapi', 'x-src' => true }
      ],
      'components' => {
        'inputs' => { 'LoginInput' => { 'type' => 'object' } },
        'parameters' => { 'authHeader' => { 'name' => 'Authorization', 'in' => 'header', 'value' => '$inputs.token' } }
      },
      'workflows' => [
        {
          'workflowId' => 'buy_pet_workflow',
          'summary' => 'Buy a pet',
          'description' => 'Logs in, creates pet, and verifies order',
          'inputs' => { 'type' => 'object', 'properties' => { 'user' => { 'type' => 'string' } } },
          'dependsOn' => ['seed_workflow'],
          'parameters' => [{ 'name' => 'trace', 'in' => 'header', 'value' => '1' }],
          'successActions' => [{ 'name' => 'endFlow', 'type' => 'end' }],
          'failureActions' => [{ 'name' => 'retryFlow', 'type' => 'retry', 'retryAfter' => 1, 'retryLimit' => 2 }],
          'outputs' => {
            'petId' => '$steps.createPet.outputs.id',
            'selected' => { 'context' => '$steps.createPet.outputs.raw', 'selector' => '/id', 'type' => 'jsonpointer' }
          },
          'x-wf' => 'custom',
          'steps' => [
            {
              'stepId' => 'createPet',
              'description' => 'Create a pet via operationId',
              'operationId' => 'add_pet',
              'parameters' => [
                { 'name' => 'user', 'in' => 'query', 'value' => '$inputs.user' },
                { 'reference' => '$components.parameters.authHeader' }
              ],
              'requestBody' => {
                'contentType' => 'application/json',
                'payload' => { 'name' => 'Rex' }
              },
              'outputs' => {
                'id' => '$response.body#/id',
                'raw' => { 'context' => '$response.body', 'selector' => '/', 'type' => 'jsonpointer' }
              }
            },
            {
              'stepId' => 'subWfStep',
              'workflowId' => 'notify_workflow',
              'parameters' => [{ 'name' => 'petId', 'in' => 'query', 'value' => '$steps.createPet.outputs.id' }]
            },
            {
              'stepId' => 'asyncStep',
              'channelPath' => '/pets/created',
              'action' => 'send',
              'parameters' => [{ 'name' => 'event', 'in' => 'query', 'value' => 'created' }]
            },
            {
              'stepId' => 'asyncNoArgStep',
              'channelPath' => '/pets/ping'
            },
            {
              'stepId' => 'pathStep',
              'operationPath' => '{$sourceDescriptions.petstore.url}#/paths/~1pets/get',
              'parameters' => [{ 'name' => 'limit', 'in' => 'query', 'value' => 10 }]
            },
            {
              'stepId' => 'pathNoArgStep',
              'operationPath' => '{$sourceDescriptions.petstore.url}#/paths/~1health/get'
            }
          ]
        },
        {
          'workflowId' => 'seed_workflow',
          'steps' => [
            { 'stepId' => 'noopStep', 'operationId' => 'ping_server' }
          ]
        }
      ]
    }
  end

  def test_arazzo_emit_and_parse_lossless_roundtrip
    spec = full_arazzo_spec
    ir = Cdd::IR.from_arazzo_hash(spec)

    ruby_code = Cdd::Arazzo::Emitter.emit(ir)
    assert_includes ruby_code, 'class WorkflowsOrchestrator'
    assert_includes ruby_code, 'def buy_pet_workflow(inputs = {})'
    assert_includes ruby_code, 'seed_workflow(inputs)'

    tokens = Ripper.lex("#{ruby_code}\n# @arazzo_unknown_inside_wf ignored\n")
    parsed_ir = Cdd::IR.new
    Cdd::Arazzo::Parser.parse(tokens, parsed_ir)

    assert_equal spec, parsed_ir.arazzo_spec
    assert_equal %w[buy_pet_workflow seed_workflow], parsed_ir.workflows

    empty_ir = Cdd::IR.new(nil, { 'arazzo' => '1.1.0', 'workflows' => [], 'sourceDescriptions' => [] })
    assert_equal '', Cdd::Arazzo::Emitter.emit(empty_ir)

    nil_ir = Cdd::IR.new(nil, {})
    assert_equal '', Cdd::Arazzo::Emitter.emit(nil_ir)

    min_spec = {
      'arazzo' => '1.1.0',
      'info' => {},
      'sourceDescriptions' => [{ 'name' => 's', 'url' => 'u', 'type' => 'openapi' }],
      'workflows' => []
    }
    min_code = Cdd::Arazzo::Emitter.emit(Cdd::IR.from_arazzo_hash(min_spec))
    assert_includes min_code, '# @arazzo 1.1.0'
    refute_includes min_code, '@arazzo_self'
  end

  def test_executed_generated_orchestrator_and_unannotated_inference
    spec = full_arazzo_spec
    ir = Cdd::IR.from_arazzo_hash(spec)
    ruby_code = Cdd::Arazzo::Emitter.emit(ir)

    sandbox = Module.new
    sandbox.module_eval(ruby_code)
    fake_client = Object.new
    fake_client.define_singleton_method(:ping_server) { { 'ok' => true } }
    fake_client.define_singleton_method(:add_pet) { |**_kwargs| { 'id' => 777 } }
    fake_client.define_singleton_method(:publish) { |*_args, **_kwargs| { 'published' => true } }
    fake_client.define_singleton_method(:request) { |*_args, **_kwargs| { 'requested' => true } }

    orch_class = sandbox.const_get(:WorkflowsOrchestrator)
    orch_class.define_method(:notify_workflow) { |**_kwargs| { 'notified' => true } }
    orch = orch_class.new({ 'petstore' => fake_client }, { self_uri: 'urn:test' })
    assert_equal({ 'petstore' => fake_client }, orch.clients)
    assert_equal({ self_uri: 'urn:test' }, orch.context)

    result = orch.buy_pet_workflow({ user: 'bob' })
    assert_equal 777, result['petId']
    assert_equal 777, result['selected']

    unannotated_ruby = <<~RUBY
      # @arazzo_summary Orphan summary before workflow
      # @arazzo_unknown_root ignored
      class CustomWorkflows
        def initialize(clients = {})
          @clients = clients
        end

        def empty_helper
          x = 1
        end

        def login_and_fetch(inputs = {})
          login_res = client.login_user(username: inputs[:username], raw_flag)
          fetch_res = client.get_profile(token: login_res['token'], mode: 'full')
          client.logout_user
          assert_equal 200, last_response.status
        end

        def test_workflow_rack_flow
          post '/login'
          assert_equal 201, last_response.status
        end
      end
    RUBY

    inferred_ir = Cdd::IR.new
    Cdd::Arazzo::Parser.parse(Ripper.lex(unannotated_ruby), inferred_ir)
    assert_equal %w[login_and_fetch rack_flow], inferred_ir.workflows
    wf1 = inferred_ir.arazzo_spec['workflows'][0]
    assert_equal '$response.body#/token', wf1['steps'][0]['outputs']['token']
    assert_equal '$steps.login.outputs.token', wf1['steps'][1]['parameters'][0]['value']
    assert_equal '$statusCode == 200', wf1['steps'][2]['successCriteria'][0]['condition']
    assert_equal 'default_api', inferred_ir.arazzo_spec['sourceDescriptions'][0]['name']
  end

  def test_cdd_parser_emitter_and_mcp_arazzo_wiring
    Dir.mktmpdir do |dir|
      arazzo_path = File.join(dir, 'arazzo.json')
      ruby_path = File.join(dir, 'workflows.rb')
      File.write(arazzo_path, JSON.pretty_generate(full_arazzo_spec))

      emitted = Cdd::Emitter.emit(arazzo_path)
      assert_includes emitted, 'class WorkflowsOrchestrator'
      File.write(ruby_path, emitted)

      merged_emitted = Cdd::Emitter.emit_from_arazzo(arazzo_path, ruby_path)
      assert_includes merged_emitted, 'class WorkflowsOrchestrator'

      parsed_json = Cdd::Parser.parse_to_arazzo(ruby_path)
      parsed_hash = JSON.parse(parsed_json)
      assert_equal '1.1.0', parsed_hash['arazzo']
      assert_equal 'buy_pet_workflow', parsed_hash['workflows'][0]['workflowId']

      router = Cdd::McpCoreRouter.new
      tool_names = router.get_tools.map { |t| t[:name] }
      assert_includes tool_names, 'parse_ruby_to_arazzo'
      assert_includes tool_names, 'emit_arazzo_to_ruby'

      mcp_parsed = JSON.parse(router.execute_tool('parse_ruby_to_arazzo', { 'filepath' => ruby_path }))
      assert_equal '1.1.0', mcp_parsed['arazzo']
      mcp_emitted = router.execute_tool('emit_arazzo_to_ruby', { 'filepath' => arazzo_path })
      assert_includes mcp_emitted, 'class WorkflowsOrchestrator'

      sdk_dir = File.join(dir, 'sdk')
      cli_dir = File.join(dir, 'cli')
      srv_dir = File.join(dir, 'srv')
      oas_path = File.join(dir, 'oas.json')
      File.write(oas_path, JSON.generate({ 'openapi' => '3.2.0', 'info' => { 'title' => 'T', 'version' => '1' }, 'paths' => {} }))
      Cdd::Emitter.emit_arazzo_sdk(input: oas_path, output: sdk_dir)
      Cdd::Emitter.emit_arazzo_sdk_cli(input: oas_path, output: cli_dir)
      Cdd::Emitter.emit_arazzo_server(input: oas_path, output: srv_dir)
      assert File.exist?(File.join(sdk_dir, 'lib', 'client.rb'))
    end
  end
end
