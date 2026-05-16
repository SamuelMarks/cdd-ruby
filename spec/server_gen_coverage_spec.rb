# frozen_string_literal: true

require_relative 'spec_helper'

class ServerGenCoverageTest < Minitest::Test
  def test_server_gen_parse_multiple_params
    code = <<~RUBY
      get '/users/:user_id/posts/:post_id' do
      end
    RUBY

    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::ServerGen::Parser.parse(tokens, ir)

    op = ir.openapi_spec['paths']['/users/{user_id}/posts/{post_id}']['get']
    assert_equal 2, op['parameters'].size
    assert_equal 'user_id', op['parameters'][0]['name']
    assert_equal 'post_id', op['parameters'][1]['name']
  end
end
