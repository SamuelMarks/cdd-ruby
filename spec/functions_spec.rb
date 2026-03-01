require_relative 'spec_helper'

class FunctionsTest < Minitest::Test
  def test_emit_api_client
    ir = Cdd::IR.new
    ir.openapi_spec["paths"] = {
      "/users/{id}" => {
        "get" => {
          "operationId" => "getUser",
          "summary" => "Gets a user",
          "parameters" => [{"name" => "id"}],
          "responses" => {"200" => {"description" => "OK"}}
        }
      }
    }
    
    out = Cdd::Functions::Emitter.emit(ir)
    assert_match(/class ApiClient/, out)
    assert_match(/def getUser\(id: nil\)/, out)
    assert_match(/# @api_client GET \/users\/\{id\}/, out)
  end

  def test_emit_api_client_with_body
    ir = Cdd::IR.new
    ir.openapi_spec["paths"] = {
      "/posts" => {
        "post" => {
          "operationId" => "createPost",
          "requestBody" => {
            "content" => {"application/json" => {}}
          },
          "responses" => {"201" => {"description" => "Created"}}
        }
      }
    }
    
    out = Cdd::Functions::Emitter.emit(ir)
    assert_match(/def createPost\(body: nil\)/, out)
  end

  def test_parse_api_client
    code = <<~RUBY
      class ApiClient
        # @api_client GET /posts
        def get_posts
        end
      end
    RUBY
    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Functions::Parser.parse(tokens, ir)
    
    assert ir.openapi_spec["paths"]["/posts"]
    assert ir.openapi_spec["paths"]["/posts"]["get"]
    assert_equal "OK", ir.openapi_spec["paths"]["/posts"]["get"]["responses"]["200"]["description"]
  end

  def test_parse_api_client_args
    code = <<~RUBY
      class ApiClient
        # @api_client GET /users/{id}
        def get_user(id:, filter: nil, body: nil)
        end
      end
    RUBY
    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Functions::Parser.parse(tokens, ir)
    
    op = ir.openapi_spec["paths"]["/users/{id}"]["get"]
    assert op["parameters"]
    assert_equal "id", op["parameters"][0]["name"]
    assert_equal "path", op["parameters"][0]["in"]
    assert_equal "filter", op["parameters"][1]["name"]
    assert_equal "query", op["parameters"][1]["in"]
    assert op["requestBody"]
  end
end
