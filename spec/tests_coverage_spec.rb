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

    out = Cdd::Tests::Emitter.emit(ir, { server: true })
    assert_match(/status=available/, out)
  end

  def test_emit_server_path_param
    code = <<~RUBY
      # @param user_id [integer] in:path
      # @route GET /users/{user_id}
      def get_user
      end
    RUBY

    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Docstrings::Parser.parse(tokens, ir)

    out = Cdd::Tests::Emitter.emit(ir, { server: true })
    assert_match(/sinatra_path\.gsub!\('\{user_id\}', '1'\)/, out)
  end
end
