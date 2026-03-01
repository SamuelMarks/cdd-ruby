require_relative 'spec_helper'
require 'fileutils'
require 'json'

class CddTest < Minitest::Test
  def setup
    File.write("dummy.rb", "# @route GET /hello\n# @schema User\nclass User\nend\n")
    File.write("dummy.json", '{"openapi":"3.2.0","paths":{"/hello":{"get":{"responses":{"200":{"description":"OK"}}}}},"components":{"schemas":{"User":{"type":"object","properties":{"name":{"type":"string"}}}}}}')
  end

  def teardown
    File.delete("dummy.rb") if File.exist?("dummy.rb")
    File.delete("dummy.json") if File.exist?("dummy.json")
  end

  def test_parser
    result = Cdd::Parser.parse("dummy.rb")
    json = JSON.parse(result)
    assert_equal "3.2.0", json["openapi"]
    assert_equal "OK", json["paths"]["/hello"]["get"]["responses"]["200"]["description"]
    assert_equal "object", json["components"]["schemas"]["User"]["type"]
  end

  def test_emitter
    result = Cdd::Emitter.emit("dummy.json")
    assert_match(/class User/, result)
    assert_match(/attr_accessor :name/, result)
    assert_match(/get '\/hello' do/, result)
  end
end
