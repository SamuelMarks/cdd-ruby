# frozen_string_literal: true

require_relative 'spec_helper'

class LinksTest < Minitest::Test
  def test_links
    code = <<~RUBY
      # @link 200 GetUserByUserId operationId:getUserById parameters.userId:$response.body#/id description:The user
      # @route GET /users
      def get_users
      end
    RUBY
    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Docstrings::Parser.parse(tokens, ir)

    op = ir.openapi_spec['paths']['/users']['get']
    l = op['responses']['200']['links']['GetUserByUserId']
    assert_equal 'getUserById', l['operationId']
    assert_equal '$response.body#/id', l['parameters']['userId']
    assert_equal 'The user', l['description']

    out = Cdd::Routes::Emitter.emit(ir)
    assert_match(
      %r{@link 200 GetUserByUserId operationId:getUserById parameters.userId:\$response.body#/id description:The user}, out
    )
  end
end
