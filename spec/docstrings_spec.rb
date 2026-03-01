require_relative 'spec_helper'

class DocstringsTest < Minitest::Test
  def test_advanced_docstrings
    code = <<~RUBY
      # @server https://api.example.com Production server
      
      # @schema User
      class User
      end
      
      # @param id [integer] in:path required:true User ID
      # @request_body [User] application/json Create User
      # @response 201 [User] application/json User created
      # @route POST /users/{id}
      def create_user
      end
    RUBY
    
    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Docstrings::Parser.parse(tokens, ir)
    
    assert_equal 1, ir.openapi_spec["servers"].size
    assert_equal "https://api.example.com", ir.openapi_spec["servers"][0]["url"]
    
    assert ir.openapi_spec["components"]["schemas"].key?("User")
    
    op = ir.openapi_spec["paths"]["/users/{id}"]["post"]
    assert op.key?("parameters")
    assert_equal "id", op["parameters"][0]["name"]
    assert_equal "path", op["parameters"][0]["in"]
    assert_equal true, op["parameters"][0]["required"]
    
    assert op.key?("requestBody")
    assert_equal "application/json", op["requestBody"]["content"].keys.first
    assert_equal "#/components/schemas/User", op["requestBody"]["content"]["application/json"]["schema"]["$ref"]
    
    assert op.key?("responses")
    assert op["responses"].key?("201")
    assert_equal "User created", op["responses"]["201"]["description"]
  end
end
