require_relative 'spec_helper'

class ComponentCallbacksTest < Minitest::Test
  def test_component_callback
    code = <<~RUBY
      # @component_callback MyCallback {$request.query.callbackUrl} post
      # @component_callback_request_body [Event] application/json description:The event
      # @component_callback_response 200 description:OK
      # @callback_ref myEvent MyCallback
      # @route POST /events
      def post_events
      end
    RUBY
    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Docstrings::Parser.parse(tokens, ir)

    cb = ir.openapi_spec["components"]["callbacks"]["MyCallback"]["{$request.query.callbackUrl}"]["post"]
    assert_equal "#/components/schemas/Event", cb["requestBody"]["content"]["application/json"]["schema"]["$ref"]
    
    op = ir.openapi_spec["paths"]["/events"]["post"]
    assert_equal "#/components/callbacks/MyCallback", op["callbacks"]["myEvent"]["$ref"]
    
    out = Cdd::Routes::Emitter.emit(ir)
    assert_match(/@component_callback MyCallback {\$request\.query\.callbackUrl} post/, out)
    assert_match(/@callback_ref myEvent MyCallback/, out)
  end
end
