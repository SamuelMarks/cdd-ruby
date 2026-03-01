require_relative 'spec_helper'

class MocksExternalTest < Minitest::Test
  def test_mocks_external
    code = <<~RUBY
      # @example_external [User] remoteUser https://example.com/user.json
      class User; end
    RUBY
    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Mocks::Parser.parse(tokens, ir)

    ex = ir.openapi_spec.dig("components", "examples", "remoteUser")
    assert_equal "https://example.com/user.json", ex["externalValue"]

    out = Cdd::Mocks::Emitter.emit(ir)
    assert_match(/@example_external \[User\] remoteUser https:\/\/example.com\/user.json/, out)
  end
end
