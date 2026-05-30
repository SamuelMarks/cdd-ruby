# frozen_string_literal: true

require_relative 'spec_helper'

class ClassesBranchTest < Minitest::Test
  def test_classes_emit_branches
    ir = Cdd::IR.new
    ir.openapi_spec['components'] = {
      'securitySchemes' => {
        'ApiKeyAuth' => {
          'type' => 'apiKey',
          'name' => 'api_key',
          'in' => 'header',
          'x-extra' => 'value'
        }
      },
      'schemas' => {
        'MySchema' => {
          'type' => 'object',
          'x-extra' => 'hello',
          'x-bool' => true,
          'x-false' => false,
          'x-int' => 42
        },
        'NoRefAllOf' => {
          'allOf' => [
            { 'type' => 'object', 'properties' => { 'foo' => { 'type' => 'string' } } }
          ]
        }
      }
    }

    out = Cdd::Classes::Emitter.emit(ir)
    assert_match(/@security_scheme ApiKeyAuth apiKey name:api_key in:header x-extra:value/, out)
    assert_match(/@schema MySchema x-extra:hello x-bool:true x-false:false/, out)
    assert_match(/class NoRefAllOf < \n/, out)
  end

  def test_classes_parse_branches
    code = <<~RUBY
      # @schema oneOf Ref1,Ref2 unknownPart
      class << self
      end

      class MissingConst <
        something_else
      end
    RUBY
    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Classes::Parser.parse(tokens, ir)
  end
end
