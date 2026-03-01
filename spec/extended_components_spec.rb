require_relative 'spec_helper'

class ExtendedComponentsTest < Minitest::Test
  def test_component_request_body
    code = <<~RUBY
      # @component_request_body UserBody [User] application/json required:true description:The user body
      # @request_body_ref UserBody
      # @route POST /users
      def post_users
      end
    RUBY
    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Docstrings::Parser.parse(tokens, ir)

    rb = ir.openapi_spec["components"]["requestBodies"]["UserBody"]
    assert_equal "#/components/schemas/User", rb["content"]["application/json"]["schema"]["$ref"]
    assert_equal true, rb["required"]
    assert_equal "The user body", rb["description"]
    
    op = ir.openapi_spec["paths"]["/users"]["post"]
    assert_equal "#/components/requestBodies/UserBody", op["requestBody"]["$ref"]
    
    out = Cdd::Routes::Emitter.emit(ir)
    assert_match(/@component_request_body UserBody \[User\] application\/json required:true description:The user body/, out)
    assert_match(/@request_body_ref UserBody/, out)
  end

  def test_component_header
    code = <<~RUBY
      # @component_header RateLimit [integer] description:Rate limit
      # @response 200 OK
      # @response_header_ref 200 X-Rate-Limit RateLimit
      # @route GET /limits
      def get_limits
      end
    RUBY
    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Docstrings::Parser.parse(tokens, ir)

    h = ir.openapi_spec["components"]["headers"]["RateLimit"]
    assert_equal "integer", h["schema"]["type"]
    assert_equal "Rate limit", h["description"]
    
    op = ir.openapi_spec["paths"]["/limits"]["get"]
    assert_equal "#/components/headers/RateLimit", op["responses"]["200"]["headers"]["X-Rate-Limit"]["$ref"]
    
    out = Cdd::Routes::Emitter.emit(ir)
    assert_match(/@component_header RateLimit \[integer\] description:Rate limit/, out)
    assert_match(/@response_header_ref 200 X-Rate-Limit RateLimit/, out)
  end

  def test_component_link
    code = <<~RUBY
      # @component_link GetUser operationId:getUser parameters.id:$response.body#/id description:Link to user
      # @response 200 OK
      # @link_ref 200 GetUserLink GetUser
      # @route GET /linked
      def get_linked
      end
    RUBY
    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Docstrings::Parser.parse(tokens, ir)

    l = ir.openapi_spec["components"]["links"]["GetUser"]
    assert_equal "getUser", l["operationId"]
    assert_equal "$response.body#/id", l["parameters"]["id"]
    assert_equal "Link to user", l["description"]
    
    op = ir.openapi_spec["paths"]["/linked"]["get"]
    assert_equal "#/components/links/GetUser", op["responses"]["200"]["links"]["GetUserLink"]["$ref"]
    
    out = Cdd::Routes::Emitter.emit(ir)
    assert_match(/@component_link GetUser operationId:getUser parameters\.id:\$response\.body#\/id description:Link to user/, out)
    assert_match(/@link_ref 200 GetUserLink GetUser/, out)
  end
end
