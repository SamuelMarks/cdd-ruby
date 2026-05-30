# frozen_string_literal: true

require_relative 'spec_helper'

class MocksCoverageTest < Minitest::Test
  def test_mocks_coverage
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
