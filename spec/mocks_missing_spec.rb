# frozen_string_literal: true

require_relative 'spec_helper'

class MocksMissingTest < Minitest::Test
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
end
