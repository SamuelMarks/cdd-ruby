require_relative 'spec_helper'

class PathParamsTest < Minitest::Test
  def test_auto_path_params
    code = <<~RUBY
      # @route GET /users/{id}/posts/{post_id}
      def get_user_post
      end
    RUBY
    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Docstrings::Parser.parse(tokens, ir)
    
    op = ir.openapi_spec["paths"]["/users/{id}/posts/{post_id}"]["get"]
    assert op.key?("parameters")
    assert_equal 2, op["parameters"].size
    assert_equal "id", op["parameters"][0]["name"]
    assert_equal "post_id", op["parameters"][1]["name"]
  end
end
