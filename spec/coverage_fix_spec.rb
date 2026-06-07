# frozen_string_literal: true

require_relative 'spec_helper'

class CoverageFixTest < Minitest::Test
  def test_client_sdk_cli_parse_mcp
    ir = Cdd::IR.new
    ir.openapi_spec = {}
    tokens = Ripper.lex("when 'mcp'\n")
    Cdd::ClientSdkCli::Parser.parse(tokens, ir)
    assert_nil ir.openapi_spec['paths']
  end

  def test_docstrings_parse_custom_type
    ir = Cdd::IR.new
    ir.openapi_spec = {}
    tokens = Ripper.lex(<<~RUBY)
      # @param name [CustomType] in:query description
      # @route GET /test
      def test_route; end
    RUBY
    Cdd::Docstrings::Parser.parse(tokens, ir)
    schema = ir.openapi_spec['paths']['/test']['get']['parameters'][0]['schema']
    assert_equal '#/components/schemas/CustomType', schema['$ref']
  end
end
