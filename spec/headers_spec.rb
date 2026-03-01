require_relative 'spec_helper'

class HeadersTest < Minitest::Test
  def test_headers
    code = <<~RUBY
      # @response_header 200 X-Rate-Limit [integer] required:true description:Rate limit in seconds
      # @route GET /headers
      def get_headers
      end
    RUBY
    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Docstrings::Parser.parse(tokens, ir)

    op = ir.openapi_spec["paths"]["/headers"]["get"]
    h = op["responses"]["200"]["headers"]["X-Rate-Limit"]
    assert_equal "integer", h["schema"]["type"]
    assert_equal true, h["required"]
    assert_equal "Rate limit in seconds", h["description"]
    
    out = Cdd::Routes::Emitter.emit(ir)
    assert_match(/@response_header 200 X-Rate-Limit \[integer\] required:true Rate limit in seconds/, out)
  end
end
