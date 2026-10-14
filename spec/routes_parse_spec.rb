# frozen_string_literal: true

require_relative 'spec_helper'
require_relative '../src/routes/parse'
require 'ripper'
require 'json'

class RoutesParseTest < Minitest::Test
  def test_route_with_parens
    code = <<~RUBY
      get('/test/with/parens') do
        "hello"
      end
    RUBY
    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Routes::Parser.parse(tokens, ir)

    assert ir.openapi_spec['paths']['/test/with/parens']['get']
  end

  def test_route_with_path_parameters
    code = <<~RUBY
      get '/users/:user_id/posts/:post_id' do
        "hello"
      end
    RUBY
    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Routes::Parser.parse(tokens, ir)

    op = ir.openapi_spec['paths']['/users/{user_id}/posts/{post_id}']['get']
    assert op

    params = op['parameters']
    assert_equal 2, params.size
    assert_equal 'user_id', params[0]['name']
    assert_equal 'post_id', params[1]['name']
  end

  def test_routes_parse_non_string_and_empty_literals
    code = <<~RUBY
      # No string literal follows method
      get 123

      # Beg token but no content
      get ""
    RUBY
    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Routes::Parser.parse(tokens, ir)
    assert_empty ir.openapi_spec['paths']
  end
end
