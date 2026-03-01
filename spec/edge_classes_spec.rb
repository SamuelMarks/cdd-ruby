require_relative 'spec_helper'

class EdgeClassesTest < Minitest::Test
  def test_edge_classes
    code = <<~RUBY
      # @schema EdgeClass justkey:justvalue
      class EdgeClass; end
    RUBY
    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Docstrings::Parser.parse(tokens, ir)

    sc = ir.openapi_spec.dig("components", "schemas", "EdgeClass")
    assert_equal "justvalue", sc["justkey"]
  end
end
