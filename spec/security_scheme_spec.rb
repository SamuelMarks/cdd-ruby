require_relative 'spec_helper'

class SecuritySchemeTest < Minitest::Test
  def test_security_scheme
    code = <<~RUBY
      # @security_scheme api_key apiKey in:header name:X-API-KEY An API key scheme
      class Auth; end
    RUBY
    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Docstrings::Parser.parse(tokens, ir)
    
    scheme = ir.openapi_spec.dig("components", "securitySchemes", "api_key")
    assert_equal "apiKey", scheme["type"]
    assert_equal "header", scheme["in"]
    assert_equal "X-API-KEY", scheme["name"]
    assert_equal "An API key scheme", scheme["description"]

    out = Cdd::Classes::Emitter.emit(ir)
    assert_match(/@security_scheme api_key apiKey in:header name:X-API-KEY An API key scheme/, out)
  end
  
  def test_security_scheme_edge
    code = <<~RUBY
      # @security_scheme bare_scheme http scheme:bearer
    RUBY
    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Docstrings::Parser.parse(tokens, ir)
    
    scheme = ir.openapi_spec.dig("components", "securitySchemes", "bare_scheme")
    assert_equal "http", scheme["type"]
    assert_equal "bearer", scheme["scheme"]
    assert_nil scheme["description"]
  end
end
