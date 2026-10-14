# frozen_string_literal: true

require_relative 'spec_helper'

class MocksTest < Minitest::Test
  def test_mocks_parse_and_emit
    code = <<~RUBY
      # @mock [User] exampleUser
      # {
      #   "id": 1,
      #   "name": "John"
      # }
      class User; end
    RUBY

    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Mocks::Parser.parse(tokens, ir)

    ex = ir.openapi_spec.dig('components', 'examples', 'exampleUser')
    assert_equal 1, ex.dig('value', 'id')
    assert_equal 'John', ex.dig('value', 'name')

    out = Cdd::Mocks::Emitter.emit(ir)
    assert_match(/@mock \[User\] exampleUser/, out)
    assert_match(/"id": 1/, out)
  end

  def test_mocks_invalid_json
    code = <<~RUBY
      # @mock [User] badUser
      # { bad json
      class User; end
    RUBY
    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Mocks::Parser.parse(tokens, ir)
    assert_nil ir.openapi_spec.dig('components', 'examples', 'badUser')
  end

  def test_mocks_primitive_and_array_values
    code = <<~RUBY
      # @mock [StringMock] StringExample
      # "just a string"
      # @mock [ArrayMock] ArrayExample
      # [1, 2, 3]
      # @example_external [StringMock] StringExt https://example.com/string.txt
    RUBY

    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Mocks::Parser.parse(tokens, ir)

    assert ir.openapi_spec['components']['examples']['StringExample']
    assert_equal 'just a string', ir.openapi_spec['components']['examples']['StringExample']['value']
    assert ir.openapi_spec['components']['examples']['ArrayExample']
    assert_equal [1, 2, 3], ir.openapi_spec['components']['examples']['ArrayExample']['value']
  end
end
