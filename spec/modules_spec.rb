# frozen_string_literal: true

require_relative 'spec_helper'

class ModulesTest < Minitest::Test
  def setup
    @ir = Cdd::IR.new
    @tokens = [
      [[1, 0], :on_comment, '# @route GET /api/v1/test', nil],
      [[2, 0], :on_comment, '# @schema Pet', nil],
      [[3, 0], :on_kw, 'class', nil],
      [[3, 6], :on_const, 'Pet', nil]
    ]
  end

  def test_classes_parse
    Cdd::Classes::Parser.parse(@tokens, @ir)
    assert_equal ['Pet'], @ir.classes
  end

  def test_classes_emit
    @ir.openapi_spec['components']['schemas']['Dog'] = { 'properties' => { 'name' => {} } }
    res = Cdd::Classes::Emitter.emit(@ir)
    assert_match(/class Dog/, res)
    assert_match(/attr_accessor :name/, res)
  end

  def test_docstrings_parse
    Cdd::Docstrings::Parser.parse(@tokens, @ir)
    assert @ir.openapi_spec['paths'].key?('/api/v1/test')
    assert @ir.openapi_spec['paths']['/api/v1/test'].key?('get')
    assert @ir.openapi_spec['components']['schemas'].key?('Pet')
  end

  def test_docstrings_emit
    assert_equal '', Cdd::Docstrings::Emitter.emit(@ir)

    @ir.openapi_spec['components']['schemas']['Pet'] = { 'description' => 'A pet schema' }
    @ir.openapi_spec['components']['schemas']['Tag'] = {}
    @ir.openapi_spec['paths']['/pets'] = {
      'summary' => 'Path summary',
      'x-custom' => 'ext',
      'get' => { 'summary' => 'List pets' },
      'post' => {}
    }
    @ir.openapi_spec['paths']['/invalid'] = 'not_a_hash'
    emitted = Cdd::Docstrings::Emitter.emit(@ir)
    assert_includes emitted, '# @schema Pet A pet schema'
    assert_includes emitted, '# @schema Tag'
    assert_includes emitted, '# @summary List pets'
    assert_includes emitted, '# @route GET /pets'
    assert_includes emitted, '# @route POST /pets'
  end

  def test_functions_parse
    tokens = Ripper.lex(<<~RUBY)
      class ApiClient
        # @api_client GET /pets/{pet_id}
        def get_pet(pet_id: nil, filter: nil)
        end
      end
    RUBY
    Cdd::Functions::Parser.parse(tokens, @ir)
    op = @ir.openapi_spec.dig('paths', '/pets/{pet_id}', 'get')
    refute_nil op
    assert_equal 2, op['parameters'].size
    assert_equal({ 'name' => 'pet_id', 'in' => 'path' }, op['parameters'][0])
    assert_equal({ 'name' => 'filter', 'in' => 'query' }, op['parameters'][1])
  end

  def test_functions_emit
    assert_equal '', Cdd::Functions::Emitter.emit(@ir)
  end

  def test_mocks_parse
    tokens = Ripper.lex(<<~RUBY)
      # @mock [Pet] samplePet
      # { "id": 1, "name": "Rex" }
    RUBY
    Cdd::Mocks::Parser.parse(tokens, @ir)
    example = @ir.openapi_spec.dig('components', 'examples', 'samplePet')
    refute_nil example
    assert_equal({ 'id' => 1, 'name' => 'Rex' }, example['value'])
  end

  def test_mocks_emit
    assert_equal '', Cdd::Mocks::Emitter.emit(@ir)
  end

  def test_openapi_parse
    tokens = Ripper.lex(<<~RUBY)
      # @api_title Petstore Service
      # @api_version 2.1.0
    RUBY
    Cdd::Openapi::Parser.parse(tokens, @ir)
    assert_equal 'Petstore Service', @ir.openapi_spec.dig('info', 'title')
    assert_equal '2.1.0', @ir.openapi_spec.dig('info', 'version')
  end

  def test_openapi_emit
    res = Cdd::Openapi::Emitter.emit(@ir)
    assert_match(/# @api_title Generated API/, res)
    assert_match(/# @api_version 0.0.4/, res)
  end

  def test_routes_parse
    tokens = Ripper.lex(<<~RUBY)
      get '/pets/:pet_id' do
      end
    RUBY
    Cdd::Routes::Parser.parse(tokens, @ir)
    op = @ir.openapi_spec.dig('paths', '/pets/{pet_id}', 'get')
    refute_nil op
    assert_equal 'pet_id', op['parameters'].first['name']
  end

  def test_routes_emit
    @ir.openapi_spec['paths']['/test'] = { 'post' => {} }
    res = Cdd::Routes::Emitter.emit(@ir)
    assert_match(%r{# @route POST /test}, res)
    assert_match(%r{post '/test' do}, res)
  end

  def test_tests_parse
    tokens = Ripper.lex(<<~RUBY)
      # @api_test GET /pets
      def test_get_pets
      end
    RUBY
    Cdd::Tests::Parser.parse(tokens, @ir)
    assert_equal 'OK', @ir.openapi_spec.dig('paths', '/pets', 'get', 'responses', '200', 'description')
  end

  def test_tests_emit
    assert_equal '', Cdd::Tests::Emitter.emit(@ir)
  end
end
