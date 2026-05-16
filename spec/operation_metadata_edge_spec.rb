# frozen_string_literal: true

require_relative 'spec_helper'

class OperationMetadataEdgeTest < Minitest::Test
  def test_operation_metadata_edges
    code = <<~RUBY
      # @param no_desc [string] in:query style:form
      # @request_body [User] application/json someOption:someValue anotherOption:false
      # @route GET /edge
      def get_edge
      end
    RUBY
    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Docstrings::Parser.parse(tokens, ir)

    op = ir.openapi_spec['paths']['/edge']['get']

    param = op['parameters'].first
    assert_equal 'no_desc', param['name']
    assert_equal 'string', param['schema']['type']
    assert_equal 'query', param['in']
    assert_equal 'form', param['style']

    rb = op['requestBody']
    assert_equal 'someValue', rb['someOption']
    assert_equal false, rb['anotherOption']
  end
end
