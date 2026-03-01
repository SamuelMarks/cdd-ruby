require_relative 'spec_helper'

class ModulesTest < Minitest::Test
  def setup
    @ir = Cdd::IR.new
    @tokens = [
      [[1, 0], :on_comment, "# @route GET /api/v1/test", nil],
      [[2, 0], :on_comment, "# @schema Pet", nil],
      [[3, 0], :on_kw, "class", nil],
      [[3, 6], :on_const, "Pet", nil]
    ]
  end

  def test_classes_parse
    Cdd::Classes::Parser.parse(@tokens, @ir)
    assert_equal ["Pet"], @ir.classes
  end

  def test_classes_emit
    @ir.openapi_spec["components"]["schemas"]["Dog"] = { "properties" => { "name" => {} } }
    res = Cdd::Classes::Emitter.emit(@ir)
    assert_match(/class Dog/, res)
    assert_match(/attr_accessor :name/, res)
  end

  def test_docstrings_parse
    Cdd::Docstrings::Parser.parse(@tokens, @ir)
    assert @ir.openapi_spec["paths"].key?("/api/v1/test")
    assert @ir.openapi_spec["paths"]["/api/v1/test"].key?("get")
    assert @ir.openapi_spec["components"]["schemas"].key?("Pet")
  end

  def test_docstrings_emit
    assert_equal "", Cdd::Docstrings::Emitter.emit(@ir)
  end

  def test_functions_parse
    Cdd::Functions::Parser.parse(@tokens, @ir)
  end

  def test_functions_emit
    assert_equal "", Cdd::Functions::Emitter.emit(@ir)
  end

  def test_mocks_parse
    Cdd::Mocks::Parser.parse(@tokens, @ir)
  end

  def test_mocks_emit
    assert_equal "", Cdd::Mocks::Emitter.emit(@ir)
  end

  def test_openapi_parse
    Cdd::Openapi::Parser.parse(@tokens, @ir)
  end

  def test_openapi_emit
    res = Cdd::Openapi::Emitter.emit(@ir)
    assert_match(/# @api_title Generated API/, res)
    assert_match(/# @api_version 0.0.1/, res)
  end

  def test_routes_parse
    Cdd::Routes::Parser.parse(@tokens, @ir)
  end

  def test_routes_emit
    @ir.openapi_spec["paths"]["/test"] = { "post" => {} }
    res = Cdd::Routes::Emitter.emit(@ir)
    assert_match(/# @route POST \/test/, res)
    assert_match(/post '\/test' do/, res)
  end

  def test_tests_parse
    Cdd::Tests::Parser.parse(@tokens, @ir)
  end

  def test_tests_emit
    assert_equal "", Cdd::Tests::Emitter.emit(@ir)
  end
end
