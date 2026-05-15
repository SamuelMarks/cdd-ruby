require_relative 'spec_helper'

class TestsTest < Minitest::Test
  def test_emit_tests_routes
    ir = Cdd::IR.new
    ir.openapi_spec["paths"] = {
      "/users/{id}" => {
        "get" => {
          "operationId" => "getUser",
          "summary" => "Gets a user",
          "parameters" => [{"name" => "id", "schema" => {"type" => "integer"}}],
          "responses" => {"200" => {"description" => "OK"}}
        },
        "put" => {
          "operationId" => "updateUser",
          "parameters" => [{"name" => "id", "schema" => {"type" => "integer"}}],
          "requestBody" => {
            "content" => {
              "application/json" => {"schema" => {"type" => "object"}}
            }
          },
          "responses" => {"204" => {"description" => "No Content"}}
        }
      },
      "/posts" => {
        "post" => {
          "operationId" => "createPost",
          "requestBody" => {
            "content" => {
              "application/json" => {"schema" => {"type" => "object"}}
            }
          },
          "responses" => {"201" => {"description" => "Created"}}
        }
      }
    }
    
    out = Cdd::Tests::Emitter.emit(ir)
    
    # General class assertion
    assert_match(/class ApiClientTest < Minitest::Test/, out)
    
    # 1. Test GET (no body, with params)
    assert_match(/def test_getUser/, out)
    assert_match(/client = ClientSdk.new\('http:\/\/localhost:8080\/v2'\)/, out)
    assert_match(/assert_equal '200', client\.last_response\.code/, out)
    
    # 2. Test PUT (with body, with params, different response code)
    assert_match(/def test_updateUser/, out)
    assert_match(/client = ClientSdk.new\('http:\/\/localhost:8080\/v2'\)/, out)
    assert_match(/assert_equal '204', client\.last_response\.code/, out)
    
    # 3. Test POST (with body, no params, different response code)
    assert_match(/def test_createPost/, out)
    assert_match(/client = ClientSdk.new\('http:\/\/localhost:8080\/v2'\)/, out)
    assert_match(/assert_equal '201', client\.last_response\.code/, out)
  end

  def test_parse_tests
    code = <<~RUBY
      class ApiClientTest < Minitest::Test
        # @api_test GET /posts
        def test_get_posts
        end
      end
    RUBY
    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Tests::Parser.parse(tokens, ir)
    
    assert ir.openapi_spec["paths"]["/posts"]
    assert ir.openapi_spec["paths"]["/posts"]["get"]
    assert_equal "OK", ir.openapi_spec["paths"]["/posts"]["get"]["responses"]["200"]["description"]
  end
end
