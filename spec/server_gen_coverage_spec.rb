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

  def test_server_gen_parse_branches
    code = <<~RUBY
      get('/users/:id')
      # some other code
    RUBY
    ir = Cdd::IR.new
    # Prepopulate the path parameter to trigger the "next if" branch at line 33
    ir.openapi_spec['paths'] = {
      '/users/{id}' => {
        'get' => {
          'parameters' => [{ 'name' => 'id', 'in' => 'path' }]
        }
      }
    }
    tokens = Ripper.lex(code)
    Cdd::ServerGen::Parser.parse(tokens, ir)

    # line 21: `current_method = token[2] if next_token && next_token[1] == :on_sp`
    # The `get('/users/:id')` doesn't have a space after `get`, so next_token is `on_lparen`, hitting the `else` (false) branch of `if next_token && next_token[1] == :on_sp`.

    # Also to ensure we hit line 33's true branch:
    # A subsequent path that does have a space:
    code2 = <<~RUBY
      get '/users/:id'
    RUBY
    tokens2 = Ripper.lex(code2)
    Cdd::ServerGen::Parser.parse(tokens2, ir)

    op = ir.openapi_spec['paths']['/users/{id}']['get']
    assert_equal 1, op['parameters'].size
  end
end
