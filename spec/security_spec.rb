# frozen_string_literal: true

require_relative 'spec_helper'

class SecurityTest < Minitest::Test
  def test_security_docstrings
    code = <<~RUBY
      # @security oauth2 read,write
      # @route GET /secure
      def secure_route
      end
    RUBY
    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Docstrings::Parser.parse(tokens, ir)

    op = ir.openapi_spec['paths']['/secure']['get']
    assert_equal 'oauth2', op['security'][0].keys.first
    assert_equal %w[read write], op['security'][0]['oauth2']

    out = Cdd::Routes::Emitter.emit(ir)
    assert_match(/@security oauth2 read, write/, out)
  end

  def test_security_empty
    code = <<~RUBY
      # @security#{' '}
      # @route GET /open
      def open_route
      end
    RUBY
    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Docstrings::Parser.parse(tokens, ir)

    op = ir.openapi_spec['paths']['/open']['get']
    assert_equal [{}], op['security']

    out = Cdd::Routes::Emitter.emit(ir)
    assert_match(/@security \n/, out)
  end
end
