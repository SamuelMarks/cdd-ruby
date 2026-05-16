# frozen_string_literal: true

require_relative 'spec_helper'

class BidirectionalTest < Minitest::Test
  def test_edit_mock_updates_schema
    code = <<~RUBY
      # @mock [User] exampleMock
      # { "name": "Alice", "age": 30, "is_active": true, "tags": ["admin"], "profile": {"theme": "dark"} }
    RUBY
    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Mocks::Parser.parse(tokens, ir)

    schema = ir.openapi_spec['components']['schemas']['User']
    assert_equal 'object', schema['type']
    assert_equal 'string', schema['properties']['name']['type']
    assert_equal 'integer', schema['properties']['age']['type']
    assert_equal 'boolean', schema['properties']['is_active']['type']
    assert_equal 'array', schema['properties']['tags']['type']
    assert_equal 'string', schema['properties']['tags']['items']['type']
    assert_equal 'object', schema['properties']['profile']['type']
    assert_equal 'string', schema['properties']['profile']['properties']['theme']['type']
  end

  def test_edit_route_updates_paths
    code = <<~RUBY
      post '/new_route' do
        status 200
      end
    RUBY
    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Routes::Parser.parse(tokens, ir)

    op = ir.openapi_spec['paths']['/new_route']['post']
    assert op
    assert_equal 'OK', op['responses']['200']['description']
  end

  def test_edit_class_updates_properties
    code = <<~RUBY
      class User
        attr_accessor :username, :email
      end
    RUBY
    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Classes::Parser.parse(tokens, ir)

    schema = ir.openapi_spec['components']['schemas']['User']
    assert_equal 'object', schema['type']
    assert_equal 'string', schema['properties']['username']['type']
    assert_equal 'string', schema['properties']['email']['type']
  end

  def test_infer_schema_edge_cases
    code = <<~RUBY
      # @mock [Edge] ex
      # { "empty_array": [], "null_val": null }
    RUBY
    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Mocks::Parser.parse(tokens, ir)

    schema = ir.openapi_spec['components']['schemas']['Edge']
    assert_equal 'object', schema['type']
    assert_equal 'array', schema['properties']['empty_array']['type']
    assert_equal({}, schema['properties']['empty_array']['items'])
    assert_equal({}, schema['properties']['null_val'])
  end

  def test_float_coverage
    code = <<~RUBY
      # @mock [FloatTest] flt
      # { "val": 3.14 }
    RUBY
    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Mocks::Parser.parse(tokens, ir)
    schema = ir.openapi_spec['components']['schemas']['FloatTest']
    assert_equal 'number', schema['properties']['val']['type']
  end
end
