require_relative 'spec_helper'

class TestsTest < Minitest::Test
  def test_emit_tests
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
    
    out = Cdd::Tests::Emitter.emit(ir)
    assert_match(/class ApiClientTest/, out)
    assert_match(/def test_getUser/, out)
    assert_match(/# @api_test GET \/users\/\{id\}/, out)
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
