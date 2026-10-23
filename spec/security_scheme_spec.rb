# frozen_string_literal: true

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

    scheme = ir.openapi_spec.dig('components', 'securitySchemes', 'api_key')
    assert_equal 'apiKey', scheme['type']
    assert_equal 'header', scheme['in']
    assert_equal 'X-API-KEY', scheme['name']
    assert_equal 'An API key scheme', scheme['description']

    out = Cdd::Classes::Emitter.emit(ir)
    assert_match(/@security_scheme api_key apiKey in:header name:X-API-KEY An API key scheme/, out)
  end

  def test_security_scheme_without_description
    code = <<~RUBY
      # @security_scheme bare_scheme http scheme:bearer
    RUBY
    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Docstrings::Parser.parse(tokens, ir)

    scheme = ir.openapi_spec.dig('components', 'securitySchemes', 'bare_scheme')
    assert_equal 'http', scheme['type']
    assert_equal 'bearer', scheme['scheme']
    assert_nil scheme['description']
  end

  def test_security_definition_and_oauth_flows
    code = <<~RUBY
      # @security_definition petstore_auth oauth2 authorizationUrl:https://petstore.swagger.io/oauth/dialog flow:implicit Swagger OAuth
      # @security_scheme oauth2_full oauth2 flows.authorizationCode.authorizationUrl:https://example.com/oauth/authorize flows.authorizationCode.tokenUrl:https://example.com/oauth/token flows.authorizationCode.refreshUrl:https://example.com/oauth/refresh flows.deviceAuthorization.deviceAuthorizationUrl:https://example.com/oauth/device
    RUBY

    tokens = Ripper.lex(code)
    ir = Cdd::IR.new
    Cdd::Docstrings::Parser.parse(tokens, ir)

    swag_def = ir.openapi_spec.dig('securityDefinitions', 'petstore_auth')
    assert_equal 'oauth2', swag_def['type']
    assert_equal 'https://petstore.swagger.io/oauth/dialog', swag_def['authorizationUrl']
    assert_equal 'Swagger OAuth', swag_def['description']

    oas_flow = ir.openapi_spec.dig('components', 'securitySchemes', 'oauth2_full', 'flows')
    assert_equal 'https://example.com/oauth/authorize', oas_flow.dig('authorizationCode', 'authorizationUrl')
    assert_equal 'https://example.com/oauth/token', oas_flow.dig('authorizationCode', 'tokenUrl')
    assert_equal 'https://example.com/oauth/refresh', oas_flow.dig('authorizationCode', 'refreshUrl')
    assert_equal 'https://example.com/oauth/device', oas_flow.dig('deviceAuthorization', 'deviceAuthorizationUrl')

    typed = ir.typed_security_schemes
    assert_equal 2, typed.size
    petstore_typed = typed.find { |s| s.name == 'petstore_auth' }
    assert_equal 'https://petstore.swagger.io/oauth/dialog', petstore_typed.authorization_url

    out = Cdd::Classes::Emitter.emit(ir)
    assert_includes out, '# @security_definition petstore_auth oauth2 ' \
                         'authorizationUrl:https://petstore.swagger.io/oauth/dialog flow:implicit Swagger OAuth'
    assert_includes out, 'flows.authorizationCode.authorizationUrl:https://example.com/oauth/authorize'
    assert_includes out, 'flows.authorizationCode.refreshUrl:https://example.com/oauth/refresh'
    assert_includes out, 'flows.deviceAuthorization.deviceAuthorizationUrl:https://example.com/oauth/device'
  end
end
