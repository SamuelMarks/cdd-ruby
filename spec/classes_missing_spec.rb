require_relative 'spec_helper'

class ClassesEmitMissingTest < Minitest::Test
  def test_classes_emit_any_of
    ir = Cdd::IR.new
    ir.openapi_spec["components"] = {
      "schemas" => {
        "UserOrAdmin" => {
          "anyOf" => [
            { "$ref" => "#/components/schemas/User" },
            { "$ref" => "#/components/schemas/Admin" }
          ]
        },
        "ParentChild" => {
          "allOf" => [
            { "$ref" => "#/components/schemas/Parent" }
          ],
          "properties" => {
            "child_prop" => {"type" => "string"}
          }
        }
      }
    }
    
    out = Cdd::Classes::Emitter.emit(ir)
    assert_match(/# @schema_any_of UserOrAdmin User, Admin/, out)
    assert_match(/class ParentChild < Parent/, out)
    assert_match(/attr_accessor :child_prop/, out)
  end
end
