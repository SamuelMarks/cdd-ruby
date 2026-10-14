# frozen_string_literal: true

require_relative 'spec_helper'

class ClassesTest < Minitest::Test
  def test_class_inheritance
    code = <<~RUBY
      class Admin < User
      end
    RUBY

    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Classes::Parser.parse(tokens, ir)

    assert_equal 1, ir.classes.size
    assert_equal 'Admin', ir.classes.first

    schema = ir.openapi_spec['components']['schemas']['Admin']
    assert schema.key?('allOf')
    assert_equal '#/components/schemas/User', schema['allOf'][0]['$ref']

    emitted = Cdd::Classes::Emitter.emit(ir)
    assert_match(/class Admin < User/, emitted)
  end

  def test_class_one_of_any_of
    code = <<~RUBY
      # @schema_one_of Pet Cat,Dog discriminator:petType mapping:cat:Cat,dog:Dog defaultMapping:Cat unknown:part
      # @schema_any_of Error NotFound,ServerError
    RUBY

    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Classes::Parser.parse(tokens, ir)

    schemas = ir.openapi_spec['components']['schemas']
    assert schemas.key?('Pet')
    assert schemas.key?('Error')

    pet_schema = schemas['Pet']
    assert_equal 2, pet_schema['oneOf'].size
    assert_equal '#/components/schemas/Cat', pet_schema['oneOf'][0]['$ref']
    assert_equal '#/components/schemas/Dog', pet_schema['oneOf'][1]['$ref']
    assert_equal 'petType', pet_schema['discriminator']['propertyName']
    assert_equal '#/components/schemas/Cat', pet_schema['discriminator']['mapping']['cat']
    assert_equal '#/components/schemas/Cat', pet_schema['discriminator']['defaultMapping']

    error_schema = schemas['Error']
    assert_equal 2, error_schema['anyOf'].size
    assert_equal '#/components/schemas/NotFound', error_schema['anyOf'][0]['$ref']
  end

  def test_parse_activerecord_class
    code = <<~RUBY
      class Post < ActiveRecord::Base
        # property: title (string)
        # property: views (integer)
      end
    RUBY
    tokens = Ripper.lex(code)
    ir = Cdd::IR.new
    Cdd::Classes::Parser.parse(tokens, ir)

    assert_equal ['Post'], ir.classes
    assert ir.openapi_spec['components']['schemas']['Post']
    assert_equal 'string', ir.openapi_spec['components']['schemas']['Post']['properties']['title']['type']
    assert_equal 'integer', ir.openapi_spec['components']['schemas']['Post']['properties']['views']['type']
  end

  def test_classes_emit_any_of_and_all_of
    ir = Cdd::IR.new
    ir.openapi_spec['components'] = {
      'schemas' => {
        'UserOrAdmin' => {
          'anyOf' => [
            { '$ref' => '#/components/schemas/User' },
            { '$ref' => '#/components/schemas/Admin' }
          ]
        },
        'ParentChild' => {
          'allOf' => [
            { '$ref' => '#/components/schemas/Parent' }
          ],
          'properties' => {
            'child_prop' => { 'type' => 'string' }
          }
        }
      }
    }

    out = Cdd::Classes::Emitter.emit(ir)
    assert_match(/# @schema_any_of UserOrAdmin User, Admin/, out)
    assert_match(/class ParentChild < Parent/, out)
    assert_match(/attr_accessor :child_prop/, out)
  end

  def test_classes_emit_extensions_and_security_schemes
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
    assert_match(/class NoRefAllOf < /, out)
  end

  def test_classes_parse_scaffolding_and_incomplete_syntax
    code = <<~RUBY
      # @schema_one_of MyUnion Ref1,Ref2 unknownPart
      class << self
      end

      class CliParser
        attr_accessor :ignored
      end

      class MissingConst <
        something_else
      end
    RUBY
    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Classes::Parser.parse(tokens, ir)
    assert_equal ['MissingConst'], ir.classes
    refute ir.openapi_spec.dig('components', 'schemas', 'CliParser')
    assert_equal 2, ir.openapi_spec.dig('components', 'schemas', 'MyUnion', 'oneOf').size

    code2 = <<~RUBY
      # @schema oneOf Ref1,Ref2 unknownPart
      class
    RUBY
    ir2 = Cdd::IR.new
    Cdd::Classes::Parser.parse(Ripper.lex(code2), ir2)
    assert_empty ir2.classes
  end
end
