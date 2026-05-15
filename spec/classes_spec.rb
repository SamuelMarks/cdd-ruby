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
    assert_equal "Admin", ir.classes.first
    
    schema = ir.openapi_spec["components"]["schemas"]["Admin"]
    assert schema.key?("allOf")
    assert_equal "#/components/schemas/User", schema["allOf"][0]["$ref"]
    
    emitted = Cdd::Classes::Emitter.emit(ir)
    assert_match(/class Admin < User/, emitted)
  end

  def test_class_one_of_any_of
    code = <<~RUBY
      # @schema_one_of Pet Cat,Dog discriminator:petType mapping:cat:Cat,dog:Dog defaultMapping:Cat
      # @schema_any_of Error NotFound,ServerError
    RUBY

    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Classes::Parser.parse(tokens, ir)

    schemas = ir.openapi_spec["components"]["schemas"]
    assert schemas.key?("Pet")
    assert schemas.key?("Error")

    pet_schema = schemas["Pet"]
    assert_equal 2, pet_schema["oneOf"].size
    assert_equal "#/components/schemas/Cat", pet_schema["oneOf"][0]["$ref"]
    assert_equal "#/components/schemas/Dog", pet_schema["oneOf"][1]["$ref"]
    assert_equal "petType", pet_schema["discriminator"]["propertyName"]
    assert_equal "#/components/schemas/Cat", pet_schema["discriminator"]["mapping"]["cat"]
    assert_equal "#/components/schemas/Cat", pet_schema["discriminator"]["defaultMapping"]

    error_schema = schemas["Error"]
    assert_equal 2, error_schema["anyOf"].size
    assert_equal "#/components/schemas/NotFound", error_schema["anyOf"][0]["$ref"]
  end
end
