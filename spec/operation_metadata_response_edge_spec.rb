require_relative 'spec_helper'

class OperationMetadataResponseEdgeTest < Minitest::Test
  def test_response_metadata_edges
    code = <<~RUBY
      # @response 400 badRequest:true
      # @route GET /response2
      def get_response
      end
    RUBY
    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Docstrings::Parser.parse(tokens, ir)

    op = ir.openapi_spec["paths"]["/response2"]["get"]
    
    resp = op["responses"]["400"]
    assert_equal "Response", resp["description"]
    assert_equal true, resp["badRequest"]
  end
  def test_response_metadata_edges_false
    code = <<~RUBY
      # @response 404 badRequest:false
      # @route GET /response3
      def get_response
      end
    RUBY
    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Docstrings::Parser.parse(tokens, ir)

    op = ir.openapi_spec["paths"]["/response3"]["get"]
    
    resp = op["responses"]["404"]
    assert_equal false, resp["badRequest"]
  end
end
