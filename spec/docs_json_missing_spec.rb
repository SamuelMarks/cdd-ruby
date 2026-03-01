require_relative 'spec_helper'

class DocsJsonEmitMissingTest < Minitest::Test
  def setup
    @filepath = "dummy_openapi.json"
    File.write(@filepath, {
      "openapi" => "3.2.0",
      "paths" => {
        "/users" => {
          "get" => {
            "operationId" => "listUsers"
          }
        }
      }
    }.to_json)
  end

  def teardown
    File.delete(@filepath) if File.exist?(@filepath)
  end

  def test_docs_json_emit
    out = Cdd::DocsJson::Emitter.emit(@filepath)
    parsed = JSON.parse(out)
    
    assert_equal 1, parsed.length
    assert_equal "ruby", parsed[0]["language"]
    
    op = parsed[0]["operations"][0]
    assert_equal "GET", op["method"]
    assert_equal "/users", op["path"]
    assert_equal "listUsers", op["operationId"]
    assert_match(/require 'net\/http'/, op["code"]["imports"])
    assert_match(/def call_listUsers/, op["code"]["wrapper_start"])
    assert_match(/end/, op["code"]["wrapper_end"])
  end
  
  def test_docs_json_emit_no_imports_no_wrapping
    out = Cdd::DocsJson::Emitter.emit(@filepath, no_imports: true, no_wrapping: true)
    parsed = JSON.parse(out)
    op = parsed[0]["operations"][0]
    
    assert_nil op["code"]["imports"]
    assert_nil op["code"]["wrapper_start"]
    assert_nil op["code"]["wrapper_end"]
  end
end
