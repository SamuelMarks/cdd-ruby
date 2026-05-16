# frozen_string_literal: true

require_relative 'spec_helper'

class OperationMetadataTest < Minitest::Test
  def test_operation_metadata
    code = <<~RUBY
      # @path_summary Operations for users
      # @path_description Contains all the operations for users
      # @deprecated
      # @external_docs https://example.com/docs User docs
      # @op_server https://us.example.com/api US server
      # @param id [integer] in:path style:simple explode:false allowReserved:true allowEmptyValue:false deprecated:true required:true The user ID
      # @request_body [User] application/json required:true A new user object
      # @route GET /users/{id}
      def get_user
      end
    RUBY
    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Docstrings::Parser.parse(tokens, ir)

    path = ir.openapi_spec['paths']['/users/{id}']
    assert_equal 'Operations for users', path['summary']
    assert_equal 'Contains all the operations for users', path['description']

    op = path['get']
    assert_equal true, op['deprecated']
    assert_equal 'https://example.com/docs', op['externalDocs']['url']
    assert_equal 'User docs', op['externalDocs']['description']

    servers = op['servers']
    assert_equal 1, servers.length
    assert_equal 'https://us.example.com/api', servers[0]['url']

    param = op['parameters'].first
    assert_equal 'id', param['name']
    assert_equal 'integer', param['schema']['type']
    assert_equal 'path', param['in']
    assert_equal 'simple', param['style']
    assert_equal false, param['explode']
    assert_equal true, param['allowReserved']
    assert_equal false, param['allowEmptyValue']
    assert_equal true, param['deprecated']
    assert_equal true, param['required']
    assert_equal 'The user ID', param['description']

    rb = op['requestBody']
    assert_equal true, rb['required']
    assert_equal 'A new user object', rb['description']
    assert_equal '#/components/schemas/User', rb['content']['application/json']['schema']['$ref']

    emitted = Cdd::Routes::Emitter.emit(ir)
    assert_match(/# @path_summary Operations for users/, emitted)
    assert_match(/# @path_description Contains all the operations for users/, emitted)
    assert_match(/# @deprecated/, emitted)
    assert_match(%r{# @external_docs https://example.com/docs User docs}, emitted)
    assert_match(%r{# @op_server https://us.example.com/api US server}, emitted)
    assert_match(
      /# @param id \[integer\] in:path required:true style:simple explode:false allowReserved:true allowEmptyValue:false deprecated:true The user ID/, emitted
    )
    assert_match(%r{# @request_body \[User\] application/json required:true A new user object}, emitted)
  end
end
