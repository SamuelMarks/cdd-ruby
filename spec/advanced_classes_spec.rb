# frozen_string_literal: true

require_relative 'spec_helper'

class AdvancedClassesTest < Minitest::Test
  def test_advanced_classes
    code = <<~RUBY
      # @schema User required:true additionalProperties:false User description goes here
      class User; end
      # @schema_one_of Pet Cat, Dog discriminator:petType mapping:cat:Cat,dog:Dog
      class Pet; end
      # @schema_one_of Animal Bird, Fish discriminator:animalType
      class Animal; end
    RUBY
    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Docstrings::Parser.parse(tokens, ir)

    user = ir.openapi_spec.dig('components', 'schemas', 'User')
    assert_equal 'object', user['type']
    assert_equal 'true', user['required']
    assert_equal 'false', user['additionalProperties']
    assert_equal 'User description goes here', user['description']

    pet = ir.openapi_spec.dig('components', 'schemas', 'Pet')
    assert_equal '#/components/schemas/Cat', pet['oneOf'][0]['$ref']
    assert_equal 'petType', pet['discriminator']['propertyName']
    assert_equal '#/components/schemas/Cat', pet['discriminator']['mapping']['cat']

    animal = ir.openapi_spec.dig('components', 'schemas', 'Animal')
    assert_equal 'animalType', animal['discriminator']['propertyName']
    assert_nil animal['discriminator']['mapping']

    out = Cdd::Classes::Emitter.emit(ir)
    assert_match(/@schema User required:true additionalProperties:false User description goes here/, out)
    assert_match(/@schema_one_of Pet Cat, Dog discriminator:petType mapping:cat:Cat,dog:Dog/, out)
    assert_match(/@schema_one_of Animal Bird, Fish discriminator:animalType/, out)
  end
end
