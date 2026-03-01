require_relative 'spec_helper'

class CallbacksTest < Minitest::Test
  def test_callbacks
    code = <<~RUBY
      # @callback myCallback {$request.query.callbackUrl} post
      # @callback_request_body [Event] application/json
      # @callback_response 200 description:Your server returns this code if it accepts the callback
      # @route POST /subscribe
      def subscribe
      end
    RUBY
    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Docstrings::Parser.parse(tokens, ir)

    op = ir.openapi_spec["paths"]["/subscribe"]["post"]
    cb = op["callbacks"]["myCallback"]["{$request.query.callbackUrl}"]["post"]
    
    assert_equal "#/components/schemas/Event", cb["requestBody"]["content"]["application/json"]["schema"]["$ref"]
    assert_equal "Your server returns this code if it accepts the callback", cb["responses"]["200"]["description"]
    
    out = Cdd::Routes::Emitter.emit(ir)
    assert_match(/@callback myCallback {\$request\.query\.callbackUrl} post/, out)
    assert_match(/@callback_request_body \[Event\] application\/json/, out)
    assert_match(/@callback_response 200 Your server returns this code if it accepts the callback/, out)
  end

  def test_callback_response_with_content
    code = <<~RUBY
      # @callback myCallback {$request.query.callbackUrl} post
      # @callback_response 200 [Success] application/json description:Success response
      # @route POST /subscribe_with_response_content
      def subscribe_res
      end
    RUBY
    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Docstrings::Parser.parse(tokens, ir)

    op = ir.openapi_spec["paths"]["/subscribe_with_response_content"]["post"]
    cb = op["callbacks"]["myCallback"]["{$request.query.callbackUrl}"]["post"]
    
    assert_equal "#/components/schemas/Success", cb["responses"]["200"]["content"]["application/json"]["schema"]["$ref"]
    assert_equal "Success response", cb["responses"]["200"]["description"]
    
    out = Cdd::Routes::Emitter.emit(ir)
    assert_match(/@callback_response 200 \[Success\] application\/json description:Success response/, out)
  end

  def test_callback_response_with_options
    code = <<~RUBY
      # @callback myCallback {$request.query.callbackUrl} post
      # @callback_response 200 [Success] application/json description:Success response true_val:true false_val:false
      # @route POST /subscribe_with_response_options
      def subscribe_res_opts
      end
    RUBY
    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Docstrings::Parser.parse(tokens, ir)

    op = ir.openapi_spec["paths"]["/subscribe_with_response_options"]["post"]
    cb = op["callbacks"]["myCallback"]["{$request.query.callbackUrl}"]["post"]
    
    assert_equal "#/components/schemas/Success", cb["responses"]["200"]["content"]["application/json"]["schema"]["$ref"]
    assert_equal "Success response", cb["responses"]["200"]["description"]
    assert_equal true, cb["responses"]["200"]["content"]["application/json"]["true_val"]
    assert_equal false, cb["responses"]["200"]["content"]["application/json"]["false_val"]
  end

  def test_callback_response_no_media_type_with_options
    code = <<~RUBY
      # @callback myCallback {$request.query.callbackUrl} post
      # @callback_response 400 description:Bad request true_val:true false_val:false
      # @route POST /subscribe_with_response_options2
      def subscribe_res_opts2
      end
    RUBY
    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Docstrings::Parser.parse(tokens, ir)

    op = ir.openapi_spec["paths"]["/subscribe_with_response_options2"]["post"]
    cb = op["callbacks"]["myCallback"]["{$request.query.callbackUrl}"]["post"]
    
    assert_equal "Bad request", cb["responses"]["400"]["description"]
    assert_equal true, cb["responses"]["400"]["true_val"]
    assert_equal false, cb["responses"]["400"]["false_val"]
  end
end
