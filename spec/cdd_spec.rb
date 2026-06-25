# frozen_string_literal: true

require_relative 'spec_helper'
require 'fileutils'
require 'json'

class CddTest < Minitest::Test
  def setup
    File.write('dummy.rb', "# @route GET /hello\n# @schema User\nclass User\nend\n")
    File.write('dummy.json',
               '{"openapi":"3.2.0","paths":{"/hello":{"get":{"responses":{"200":{"description":"OK"}}}}},"components":{"schemas":{"User":{"type":"object","properties":{"name":{"type":"string"}}}}}}')
  end

  def teardown
    FileUtils.rm_f('dummy.rb')
    FileUtils.rm_f('dummy.json')
  end

  def test_parser
    result = Cdd::Parser.parse('dummy.rb')
    json = JSON.parse(result)
    assert_equal '3.2.0', json['openapi']
    assert_equal 'OK', json['paths']['/hello']['get']['responses']['200']['description']
    assert_equal 'object', json['components']['schemas']['User']['type']

    # Test array of filepaths including a missing one
    result_missing = Cdd::Parser.parse(['dummy.rb', 'does_not_exist.rb'])
    json_missing = JSON.parse(result_missing)
    assert_equal '3.2.0', json_missing['openapi']
  end

  def test_emitter
    result = Cdd::Emitter.emit('dummy.json')
    assert_match(/class User/, result)
    assert_match(/attr_accessor :name/, result)
    assert_match(%r{get '/hello' do}, result)
  end

  def test_mcp_core_router
    router = Cdd::McpCoreRouter.new
    tools = router.get_tools
    assert_equal 2, tools.length
    assert_equal 'parse_ruby_to_openapi', tools[0][:name]
    assert_equal 'emit_openapi_to_ruby', tools[1][:name]

    res_parse = router.execute_tool('parse_ruby_to_openapi', { 'filepath' => 'dummy.rb' })
    assert res_parse.is_a?(String)
    assert_match(/"openapi": "3.2.0"/, res_parse)

    res_emit = router.execute_tool('emit_openapi_to_ruby', { 'filepath' => 'dummy.json' })
    assert res_emit.is_a?(String)
    assert_match(/class User/, res_emit)

    assert_raises(RuntimeError) { router.execute_tool('unknown_tool', {}) }

    resources = router.get_resources
    assert_equal 1, resources.length
    assert_equal 'mcp://cdd/ast', resources[0][:uri]

    roots = router.get_roots
    assert_equal 0, roots.length

    templates = router.get_resource_templates
    assert_equal 0, templates.length

    sample = router.sample_message
    assert_equal 'sampled', sample[:content][:text]

    completion = router.complete_prompt('a', 'b', 'c')
    assert_equal 0, completion[:completion][:total]

    res_content = router.read_resource('mcp://cdd/ast')
    assert_equal 'mcp://cdd/ast', res_content[:contents][0][:uri]

    assert_raises(RuntimeError) { router.read_resource('mcp://unknown') }

    assert_nil router.subscribe('uri')
    assert_nil router.unsubscribe('uri')
    assert router.ping
    assert_nil router.set_level('debug')
    assert_nil router.cancelled('id')
    assert_nil router.progress('token', 1, 2)
    assert_equal [], router.get_prompts
    assert_equal({}, router.get_prompt('name', {}))
    assert_equal({ completion: { values: [], total: 0, hasMore: false } }, router.complete('n', 'a', 'v'))
  end
end

class CddEmitterCliTest < Minitest::Test
  def setup
    File.write('dummy.json',
               '{"openapi":"3.2.0","info":{"title":"My API"},"paths":{"/hello/{id}":{"get":{"operationId":"get_hello","responses":{"200":{"description":"OK"}}}}}}')
  end

  def teardown
    FileUtils.rm_f('dummy.json')
    FileUtils.rm_f('sdk_cli.rb')
    FileUtils.rm_f('server.rb')
  end

  def test_emit_sdk_cli
    res = Cdd::Emitter.emit_sdk_cli(input: 'dummy.json', output: '.')
    assert_match(/get_hello/, res)
    assert File.exist?('sdk_cli.rb')

    # test without paths
    File.write('dummy_no_paths.json', '{"openapi":"3.2.0","info":{"title":"API"}}')
    res2 = Cdd::Emitter.emit_sdk_cli(input: 'dummy_no_paths.json')
    assert_match(/Usage: sdk_cli/, res2)
    File.delete('dummy_no_paths.json')
  end

  def test_emit_server
    out_dir = 'test_cdd_spec_server_out'
    Cdd::Emitter.emit_server(input: 'dummy.json', output: out_dir)
    assert File.exist?(File.join(out_dir, 'server.rb'))
    routes_out = File.read(File.join(out_dir, 'routes', 'general_routes.rb'))
    assert_match(%r{get '/hello/:id' do}, routes_out)

    File.write('dummy_no_paths.json', '{"openapi":"3.2.0"}')
    res2 = Cdd::Emitter.emit_server(input: 'dummy_no_paths.json', output: out_dir)
    assert_match(/require 'sinatra'/, res2)
    File.delete('dummy_no_paths.json')
    FileUtils.rm_rf(out_dir)
  end
end
