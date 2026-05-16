# frozen_string_literal: true

require_relative 'spec_helper'

class TestsCoverageTest < Minitest::Test
  def test_emit_status_param
    code = <<~RUBY
      # @param status [string] in:query
      # @route GET /test
      def test_route
      end
    RUBY

    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Docstrings::Parser.parse(tokens, ir)

    out = Cdd::Tests::Emitter.emit(ir)
    assert_match(/status: 'available'/, out)
  end
end
