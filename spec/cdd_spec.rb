# frozen_string_literal: true

require_relative 'spec_helper'
require 'fileutils'
require 'json'
require 'tempfile'
require 'tmpdir'

class CddTest < Minitest::Test
  def setup
    @tmp_dir = Dir.mktmpdir
    @rb_path = File.join(@tmp_dir, 'sample.rb')
    @json_path = File.join(@tmp_dir, 'sample.json')
    File.write(@rb_path, "# @route GET /hello
# @schema User
class User
end
")
    File.write(@json_path,
               '{"openapi":"3.2.0","paths":{"/hello":{"get":{"responses":{"200":{"description":"OK"}}}}},"components":{"schemas":{"User":{"type":"object","properties":{"name":{"type":"string"}}}}}}')
  end

  def teardown
    FileUtils.rm_rf(@tmp_dir)
  end

  def test_parser
    result = Cdd::Parser.parse(@rb_path)
    json = JSON.parse(result)
    assert_equal '3.2.0', json['openapi']
    assert_equal 'OK', json['paths']['/hello']['get']['responses']['200']['description']
    assert_equal 'object', json['components']['schemas']['User']['type']

    # Test array of filepaths including a non-existent one
    result_partial = Cdd::Parser.parse([@rb_path, File.join(@tmp_dir, 'does_not_exist.rb')])
    json_partial = JSON.parse(result_partial)
    assert_equal '3.2.0', json_partial['openapi']
  end

  def test_emitter
    result = Cdd::Emitter.emit(@json_path)
    assert_match(/class User/, result)
    assert_match(/attr_accessor :name/, result)
    assert_match(%r{get '/hello' do}, result)
  end

  def test_emit_with_original_file_merges_ast
    openapi_file = Tempfile.new(['openapi', '.json'])
    openapi_file.write(JSON.generate({
                                       'openapi' => '3.2.0',
                                       'info' => { 'title' => 'Updated API', 'version' => '2.0.0' },
                                       'paths' => {
                                         '/new_route' => {
                                           'post' => { 'responses' => { '201' => { 'description' => 'Created' } } }
                                         }
                                       }
                                     }))
    openapi_file.close

    ruby_file = Tempfile.new(['original', '.rb'])
    ruby_file.write(<<~RUBY)
      # @route GET /existing_route
      class ExistingModel
        attr_accessor :id
      end
    RUBY
    ruby_file.close

    out = Cdd::Emitter.emit(openapi_file.path, ruby_file.path)
    assert_match(/# @api_title Updated API/, out)
    assert_match(/class ExistingModel/, out)
    assert_match(%r{get '/existing_route' do}, out)
    assert_match(%r{post '/new_route' do}, out)
  ensure
    openapi_file.unlink
    ruby_file.unlink
  end

  def test_mcp_core_router
    router = Cdd::McpCoreRouter.new
    tools = router.get_tools
    assert_equal 4, tools.length
    assert_equal 'parse_ruby_to_openapi', tools[0][:name]
    assert_equal 'emit_openapi_to_ruby', tools[1][:name]
    assert_equal 'parse_ruby_to_arazzo', tools[2][:name]
    assert_equal 'emit_arazzo_to_ruby', tools[3][:name]

    res_parse = router.execute_tool('parse_ruby_to_openapi', { 'filepath' => @rb_path })
    assert res_parse.is_a?(String)
    assert_match(/"openapi": "3.2.0"/, res_parse)

    res_emit = router.execute_tool('emit_openapi_to_ruby', { 'filepath' => @json_path })
    assert res_emit.is_a?(String)
    assert_match(/class User/, res_emit)

    assert_raises(Cdd::McpError) { router.execute_tool('unknown_tool', {}) }

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

    blob_content = router.read_resource('mcp://cdd/blob')
    assert_equal 'Y2Rk', blob_content[:contents][0][:blob]

    assert_raises(Cdd::McpError) { router.read_resource('mcp://unknown') }

    assert_nil router.subscribe('uri')
    assert_nil router.unsubscribe('uri')
    assert_nil router.initialized
    assert_nil router.close
    assert router.ping
    assert_equal({}, router.dispatch_common_method('notifications/initialized'))
    assert_equal({}, router.dispatch_common_method('close'))
    assert_nil router.set_level('debug')
    assert_nil router.cancelled('id')
    assert_nil router.progress('token', 1, 2)
    assert_equal [], router.get_prompts
    assert_equal({}, router.get_prompt('name', {}))
    assert_equal({ completion: { values: [], total: 0, hasMore: false } }, router.complete('n', 'a', 'v'))
  end

  def test_gemspec_and_gemfile_compatibility
    root_dir = File.expand_path('..', __dir__)
    spec = Gem::Specification.load(File.join(root_dir, 'cdd-ruby.gemspec'))
    assert_equal ['MIT', 'Apache-2.0'], spec.licenses
    assert_equal Gem::Requirement.new('>= 3.0.0'), spec.required_ruby_version
    runtime_deps = spec.runtime_dependencies.to_h { |d| [d.name, d.requirement] }
    assert_equal Gem::Requirement.new('>= 3.0'), runtime_deps['bigdecimal']
    assert_equal Gem::Requirement.new('~> 1.8'), runtime_deps['webrick']
    assert_equal %w[bigdecimal webrick], runtime_deps.keys.sort
    assert_includes spec.files, 'Rakefile'

    gemfile_content = File.read(File.join(root_dir, 'Gemfile'))
    assert_includes gemfile_content, "gem 'rake', '~> 13.0'"
    assert_includes gemfile_content, "gem 'minitest', '>= 5.0'"

    rakefile_content = File.read(File.join(root_dir, 'Rakefile'))
    assert_includes rakefile_content, 'task :test'
    assert_includes rakefile_content, 'rspec'

    makefile_content = File.read(File.join(root_dir, 'Makefile'))
    assert_includes makefile_content, "build_wasm:\n\t@BIN_DIR=$${BIN_DIR:-dist} python3 scripts/build_wasm.py"

    make_bat_content = File.read(File.join(root_dir, 'make.bat'))
    assert_includes make_bat_content, 'python scripts/build_wasm.py'

    build_wasm_content = File.read(File.join(root_dir, 'scripts', 'build_wasm.py'))
    assert_includes build_wasm_content, 'extend_ruby_path'
    assert_includes build_wasm_content, 'Gem.bindir'
    assert_includes build_wasm_content, 'cdd-ruby.wasm'
    assert_includes build_wasm_content, 'build_pruned_usr_dir'
    assert_includes build_wasm_content, 'optimize_wasm_binary'
  end
end

class CddEmitterCliTest < Minitest::Test
  def setup
    @tmp_dir = Dir.mktmpdir
    @json_path = File.join(@tmp_dir, 'sample.json')
    File.write(@json_path,
               '{"openapi":"3.2.0","info":{"title":"My API"},"paths":{"/hello/{id}":{"get":{"operationId":"get_hello","responses":{"200":{"description":"OK"}}}}}}')
  end

  def teardown
    FileUtils.rm_rf(@tmp_dir)
  end

  def test_emit_sdk_cli
    res = Cdd::Emitter.emit_sdk_cli(input: @json_path, output: @tmp_dir)
    assert_match(/get_hello/, res)
    assert File.exist?(File.join(@tmp_dir, 'sdk_cli.rb'))
    assert RubyVM::InstructionSequence.compile(res)

    no_paths_json = File.join(@tmp_dir, 'no_paths.json')
    File.write(no_paths_json, '{"openapi":"3.2.0","info":{"title":"API"}}')
    res2 = Cdd::Emitter.emit_sdk_cli(input: no_paths_json)
    assert_match(/Usage: sdk_cli/, res2)
    assert RubyVM::InstructionSequence.compile(res2)
  end

  def test_emit_server
    out_dir = File.join(@tmp_dir, 'server_out')
    Cdd::Emitter.emit_server(input: @json_path, output: out_dir)
    assert File.exist?(File.join(out_dir, 'server.rb'))
    Dir.glob(File.join(out_dir, '**', '*.rb')).each do |rb_file|
      assert RubyVM::InstructionSequence.compile(File.read(rb_file)), "Invalid syntax in #{rb_file}"
    end
    routes_out = File.read(File.join(out_dir, 'routes', 'general_routes.rb'))
    assert_match(%r{get '/hello/:id' do}, routes_out)

    no_paths_json = File.join(@tmp_dir, 'no_paths.json')
    File.write(no_paths_json, '{"openapi":"3.2.0"}')
    res2 = Cdd::Emitter.emit_server(input: no_paths_json, output: out_dir)
    assert_match(/require 'sinatra'/, res2)
    assert RubyVM::InstructionSequence.compile(res2)
  end
end
