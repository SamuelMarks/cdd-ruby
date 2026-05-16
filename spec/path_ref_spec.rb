# frozen_string_literal: true

require_relative 'spec_helper'

class PathRefTest < Minitest::Test
  def test_path_ref
    code = <<~CODE
      # @route_ref /items MyPathItem
    CODE
    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Docstrings::Parser.parse(tokens, ir)

    assert_equal '#/components/pathItems/MyPathItem', ir.openapi_spec['paths']['/items']['$ref']

    out = Cdd::Routes::Emitter.emit(ir)
    assert_match(%r{@route_ref /items MyPathItem}, out)
  end
end
