require_relative 'spec_helper'

class ServerVariablesTest < Minitest::Test
  def test_server_variables
    code = <<~CODE
      # @server https://api.example.com/{version} Production
      # @server_var https://api.example.com/{version} version v1 enum:v1,v2 description:API version
      # @op_server https://{region}.api.example.com Regional
      # @op_server_var https://{region}.api.example.com region us-east enum:us-east,eu-west
      # @route GET /vars
      def get_vars
      end
    CODE
    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Docstrings::Parser.parse(tokens, ir)

    srv = ir.openapi_spec["servers"][0]
    assert_equal "v1", srv["variables"]["version"]["default"]
    assert_equal ["v1", "v2"], srv["variables"]["version"]["enum"]
    assert_equal "API version", srv["variables"]["version"]["description"]

    op = ir.openapi_spec["paths"]["/vars"]["get"]
    osrv = op["servers"][0]
    assert_equal "us-east", osrv["variables"]["region"]["default"]
    assert_equal ["us-east", "eu-west"], osrv["variables"]["region"]["enum"]

    out = Cdd::Routes::Emitter.emit(ir)
    assert_match(/@server_var https:\/\/api.example.com\/\{version\} version v1 enum:v1,v2 description:API version/, out)
    assert_match(/@op_server_var https:\/\/\{region\}\.api\.example\.com region us-east enum:us-east,eu-west/, out)
  end

  def test_implicit_op_server_var
    code = <<~CODE
      # @op_server_var https://{region}.api.example.com region us-east enum:us-east description:My region var
      # @route GET /implicit_vars
      def get_impl
      end
    CODE
    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Docstrings::Parser.parse(tokens, ir)

    op = ir.openapi_spec["paths"]["/implicit_vars"]["get"]
    osrv = op["servers"][0]
    assert_equal "https://{region}.api.example.com", osrv["url"]
    assert_equal "us-east", osrv["variables"]["region"]["default"]
    assert_equal ["us-east"], osrv["variables"]["region"]["enum"]
    assert_equal "My region var", osrv["variables"]["region"]["description"]
  end
end
