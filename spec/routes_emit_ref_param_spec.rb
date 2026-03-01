require_relative 'spec_helper'

class RoutesEmitRefParamTest < Minitest::Test
  def test_ref_param
    ir = Cdd::IR.new
    op = {
      "parameters" => [
        {"name" => "userId", "in" => "query", "schema" => {"$ref" => "#/components/schemas/User"}}
      ]
    }
    ir.openapi_spec["paths"] = { "/user" => { "get" => op } }
    
    out = Cdd::Routes::Emitter.emit(ir)
    assert_match(/# @param userId \[User\] in:query/, out)
  end
end
