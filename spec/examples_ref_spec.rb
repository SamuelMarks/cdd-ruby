require_relative 'spec_helper'

class ExamplesRefTest < Minitest::Test
  def test_examples_ref
    code = <<~CODE
      # @param q [string] in:query
      # @param_example_ref q ValidQuery ValidExample
      # @request_body [Item] application/json
      # @request_body_example_ref application/json ValidBody ValidBodyExample
      # @response 200 [Item] application/json
      # @response_example_ref 200 application/json ValidResp ValidRespExample
      # @route POST /examples
      def post_examples
      end
    CODE
    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Docstrings::Parser.parse(tokens, ir)

    op = ir.openapi_spec["paths"]["/examples"]["post"]
    assert_equal "#/components/examples/ValidExample", op["parameters"][0]["examples"]["ValidQuery"]["$ref"]
    assert_equal "#/components/examples/ValidBodyExample", op["requestBody"]["content"]["application/json"]["examples"]["ValidBody"]["$ref"]
    assert_equal "#/components/examples/ValidRespExample", op["responses"]["200"]["content"]["application/json"]["examples"]["ValidResp"]["$ref"]

    out = Cdd::Routes::Emitter.emit(ir)
    assert_match(/@param_example_ref q ValidQuery ValidExample/, out)
    assert_match(/@request_body_example_ref application\/json ValidBody ValidBodyExample/, out)
    assert_match(/@response_example_ref 200 application\/json ValidResp ValidRespExample/, out)
  end
end
