require_relative 'spec_helper'

class ComponentsTest < Minitest::Test
  def test_component_param
    code = <<~RUBY
      # @component_param limit [integer] in:query required:true description:Max records to return
      # @param_ref limit
      # @route GET /items
      def get_items
      end
    RUBY
    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Docstrings::Parser.parse(tokens, ir)

    p = ir.openapi_spec["components"]["parameters"]["limit"]
    assert_equal "query", p["in"]
    assert_equal "integer", p["schema"]["type"]
    assert_equal true, p["required"]
    assert_equal "Max records to return", p["description"]
    
    op = ir.openapi_spec["paths"]["/items"]["get"]
    assert_equal "#/components/parameters/limit", op["parameters"][0]["$ref"]
    
    out = Cdd::Routes::Emitter.emit(ir)
    assert_match(/@component_param limit \[integer\] in:query required:true Max records to return/, out)
    assert_match(/@param_ref limit/, out)
  end

  def test_component_response
    code = <<~RUBY
      # @component_response BadRequest [Error] application/json description:Bad Request
      # @response_ref 400 BadRequest
      # @route GET /err
      def get_err
      end
    RUBY
    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Docstrings::Parser.parse(tokens, ir)

    r = ir.openapi_spec["components"]["responses"]["BadRequest"]
    assert_equal "#/components/schemas/Error", r["content"]["application/json"]["schema"]["$ref"]
    assert_equal "Bad Request", r["description"]
    
    op = ir.openapi_spec["paths"]["/err"]["get"]
    assert_equal "#/components/responses/BadRequest", op["responses"]["400"]["$ref"]
    
    out = Cdd::Routes::Emitter.emit(ir)
    assert_match(/@component_response BadRequest \[Error\] application\/json description:Bad Request/, out)
    assert_match(/@response_ref 400 BadRequest/, out)
  end
  
  def test_component_response_no_media
    code = <<~RUBY
      # @component_response NotFound description:Not Found
      # @route GET /nf
      def get_nf
      end
    RUBY
    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Docstrings::Parser.parse(tokens, ir)

    r = ir.openapi_spec["components"]["responses"]["NotFound"]
    assert_equal "Not Found", r["description"]
    
    out = Cdd::Routes::Emitter.emit(ir)
    assert_match(/@component_response NotFound description:Not Found/, out)
  end
end
