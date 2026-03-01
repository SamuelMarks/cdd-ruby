require_relative 'spec_helper'

class IrMissingTest < Minitest::Test
  def test_ir_to_h
    ir = Cdd::IR.new
    hash = ir.to_h
    assert_equal ["classes", "routes", "openapi", "tests", "mocks"].sort, hash.keys.sort
    assert_equal "3.2.0", hash["openapi"]["openapi"]
  end
end
