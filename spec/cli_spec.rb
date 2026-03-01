require_relative 'spec_helper'

class CliTest < Minitest::Test
  def setup
    File.write("dummy.rb", "# @route GET /hello\nclass User\nend\n")
    File.write("dummy.json", '{"openapi":"3.2.0","paths":{"/hello":{"get":{"operationId":"say_hello","responses":{"200":{"description":"OK"}}}}}}')
  end

  def teardown
    ["spec.json", "docs.json", "server.rb", "sdk.rb", "sdk_cli.rb"].each { |f| File.delete(f) if File.exist?(f) }
    File.delete("dummy.rb") if File.exist?("dummy.rb")
    File.delete("dummy.json") if File.exist?("dummy.json")
  end

  def test_cli_help
    output = `bundle exec ruby bin/cdd-ruby -h`
    assert_match(/Usage: cdd-ruby/, output)
    assert_match(/from_openapi/, output)
    assert_match(/to_openapi/, output)
    assert_match(/to_docs_json/, output)
  end

  def test_cli_version
    output = `bundle exec ruby bin/cdd-ruby -v`
    assert_match(/0\.0\.1/, output)
  end

  def test_cli_to_openapi
    `bundle exec ruby bin/cdd-ruby to_openapi -f dummy.rb`
    output = File.read("spec.json")
    json = JSON.parse(output)
    assert_equal "3.2.0", json["openapi"]
  end

  def test_cli_from_openapi
    `bundle exec ruby bin/cdd-ruby from_openapi --no-installable-package --no-github-actions to_server -i dummy.json`
    output = File.read("server.rb")
    assert_match(/get '\/hello' do/, output)
  end

  def test_cli_from_openapi_sdk
    `bundle exec ruby bin/cdd-ruby from_openapi --no-installable-package --no-github-actions to_sdk -i dummy.json`
    output = File.read("sdk.rb")
    assert_match(/def say_hello/, output)
  end

  def test_cli_from_openapi_sdk_cli
    `bundle exec ruby bin/cdd-ruby from_openapi --no-installable-package --no-github-actions to_sdk_cli -i dummy.json`
    output = File.read("sdk_cli.rb")
    assert_match(/Auto-generated SDK CLI for/, output)
    assert_match(/say_hello/, output)
  end

  def test_cli_to_docs_json
    `bundle exec ruby bin/cdd-ruby to_docs_json -i dummy.json`
    output = File.read("docs.json")
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
    `bundle exec ruby bin/cdd-ruby to_docs_json --no-imports --no-wrapping -i dummy.json`
    output = File.read("docs.json")
    json = JSON.parse(output)
    
    code = json[0]["operations"][0]["code"]
    assert_nil code["imports"]
    assert_nil code["wrapper_start"]
    assert_nil code["wrapper_end"]
    assert_match(/Net::HTTP\.get/, code["snippet"])
  end

  def test_cli_scaffolding
    out_dir = "scaffold_test_dir"
    `bundle exec ruby bin/cdd-ruby from_openapi to_sdk -i dummy.json -o #{out_dir}`
    assert File.exist?("#{out_dir}/sdk.rb")
    assert File.exist?("#{out_dir}/generated_project.gemspec")
    assert File.exist?("#{out_dir}/Gemfile")
    assert File.exist?("#{out_dir}/.github/workflows/ci.yml")
    FileUtils.rm_rf(out_dir)
  end
end
