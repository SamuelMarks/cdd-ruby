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
end
