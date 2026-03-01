require_relative 'spec_helper'

class CliTest < Minitest::Test
  def setup
    File.write("dummy.rb", "# @route GET /hello\nclass User\nend\n")
    File.write("dummy.json", '{"openapi":"3.2.0","paths":{"/hello":{"get":{"operationId":"say_hello","responses":{"200":{"description":"OK"}}}}}}')
  end

  def teardown
    File.delete("dummy.rb") if File.exist?("dummy.rb")
    File.delete("dummy.json") if File.exist?("dummy.json")
  end

  def test_cli_help
    output = `ruby bin/cdd-ruby -h`
    assert_match(/Usage: cdd-ruby/, output)
    assert_match(/from_openapi/, output)
    assert_match(/to_openapi/, output)
    assert_match(/to_docs_json/, output)
  end

  def test_cli_version
    output = `ruby bin/cdd-ruby -v`
    assert_match(/1\.0\.0/, output)
  end

  def test_cli_to_openapi
    output = `ruby bin/cdd-ruby to_openapi -f dummy.rb`
    json = JSON.parse(output)
    assert_equal "3.2.0", json["openapi"]
  end

  def test_cli_from_openapi
    output = `ruby bin/cdd-ruby from_openapi -i dummy.json`
    assert_match(/get '\/hello' do/, output)
  end

  def test_cli_to_docs_json
    output = `ruby bin/cdd-ruby to_docs_json -i dummy.json`
    json = JSON.parse(output)
    assert_equal "ruby", json[0]["language"]
    
    op = json[0]["operations"][0]
    assert_equal "GET", op["method"]
    assert_equal "/hello", op["path"]
    assert_equal "say_hello", op["operationId"]
    
    code = op["code"]
    assert_match(/require 'net\/http'/, code["imports"])
    assert_match(/def call_say_hello/, code["wrapper_start"])
    assert_match(/Net::HTTP\.get/, code["snippet"])
    assert_match(/end/, code["wrapper_end"])
  end

  def test_cli_to_docs_json_toggles
    output = `ruby bin/cdd-ruby to_docs_json --no-imports --no-wrapping -i dummy.json`
    json = JSON.parse(output)
    
    code = json[0]["operations"][0]["code"]
    assert_nil code["imports"]
    assert_nil code["wrapper_start"]
    assert_nil code["wrapper_end"]
    assert_match(/Net::HTTP\.get/, code["snippet"])
  end
end
