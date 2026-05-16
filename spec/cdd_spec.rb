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
    File.delete('dummy.rb') if File.exist?('dummy.rb')
    File.delete('dummy.json') if File.exist?('dummy.json')
  end

  def test_parser
    result = Cdd::Parser.parse('dummy.rb')
    json = JSON.parse(result)
    assert_equal '3.2.0', json['openapi']
    assert_equal 'OK', json['paths']['/hello']['get']['responses']['200']['description']
    assert_equal 'object', json['components']['schemas']['User']['type']
  end

  def test_emitter
    result = Cdd::Emitter.emit('dummy.json')
    assert_match(/class User/, result)
    assert_match(/attr_accessor :name/, result)
    assert_match(%r{get '/hello' do}, result)
  end
end

class CddEmitterCliTest < Minitest::Test
  def setup
    File.write('dummy.json',
               '{"openapi":"3.2.0","info":{"title":"My API"},"paths":{"/hello/{id}":{"get":{"operationId":"get_hello","responses":{"200":{"description":"OK"}}}}}}')
  end

  def teardown
    File.delete('dummy.json') if File.exist?('dummy.json')
    File.delete('sdk_cli.rb') if File.exist?('sdk_cli.rb')
    File.delete('server.rb') if File.exist?('server.rb')
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
    res = Cdd::Emitter.emit_server(input: 'dummy.json', output: '.')
    assert_match(%r{get '/hello/:id' do}, res)
    assert File.exist?('server.rb')

    File.write('dummy_no_paths.json', '{"openapi":"3.2.0"}')
    res2 = Cdd::Emitter.emit_server(input: 'dummy_no_paths.json')
    assert_match(/require 'sinatra'/, res2)
    File.delete('dummy_no_paths.json')
  end
end
