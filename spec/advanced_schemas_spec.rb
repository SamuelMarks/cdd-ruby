require_relative 'spec_helper'

class AdvancedSchemasTest < Minitest::Test
  def test_one_of_parse
    code = <<~RUBY
      # @schema_one_of Pet Cat, Dog
    RUBY
    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Docstrings::Parser.parse(tokens, ir)
    
    schema = ir.openapi_spec["components"]["schemas"]["Pet"]
    assert schema.key?("oneOf")
    assert_equal 2, schema["oneOf"].size
    assert_equal "#/components/schemas/Cat", schema["oneOf"][0]["$ref"]
    assert_equal "#/components/schemas/Dog", schema["oneOf"][1]["$ref"]
  end

  def test_any_of_parse
    code = <<~RUBY
      # @schema_any_of SearchResult User, Organization
    RUBY
    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Docstrings::Parser.parse(tokens, ir)
    
    schema = ir.openapi_spec["components"]["schemas"]["SearchResult"]
    assert schema.key?("anyOf")
    assert_equal 2, schema["anyOf"].size
    assert_equal "#/components/schemas/User", schema["anyOf"][0]["$ref"]
    assert_equal "#/components/schemas/Organization", schema["anyOf"][1]["$ref"]
  end
  
  def test_one_of_emit
    ir = Cdd::IR.new
    ir.openapi_spec["components"] = {
      "schemas" => {
        "Pet" => {
          "oneOf" => [
            { "$ref" => "#/components/schemas/Cat" },
            { "$ref" => "#/components/schemas/Dog" }
          ]
        }
      }
    }
    res = Cdd::Classes::Emitter.emit(ir)
    assert_match(/# @schema_one_of Pet Cat, Dog/, res)
  end
end
