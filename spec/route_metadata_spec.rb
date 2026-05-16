# frozen_string_literal: true

require_relative 'spec_helper'

class RouteMetadataTest < Minitest::Test
  def test_route_metadata
    code = <<~RUBY
      # @operationId listUsers
      # @summary Get users
      # @description Fetches all users from the database
      # @tag Users
      # @tag Admin
      # @route GET /users
      def list_users
      end
    RUBY
    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Docstrings::Parser.parse(tokens, ir)

    op = ir.openapi_spec['paths']['/users']['get']
    assert_equal 'listUsers', op['operationId']
    assert_equal 'Get users', op['summary']
    assert_equal 'Fetches all users from the database', op['description']
    assert_equal %w[Users Admin], op['tags']

    emitted = Cdd::Routes::Emitter.emit(ir)
    assert_match(/# @operationId listUsers/, emitted)
    assert_match(/# @summary Get users/, emitted)
    assert_match(/# @description Fetches all users from the database/, emitted)
    assert_match(/# @tag Users/, emitted)
    assert_match(/# @tag Admin/, emitted)
  end
end
