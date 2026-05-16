# frozen_string_literal: true

require_relative 'spec_helper'

class WebhooksTest < Minitest::Test
  def test_webhook
    code = <<~RUBY
      # @request_body [Pet] application/json Information about a new pet
      # @response 200 Return a 200 status to indicate that the data was received successfully
      # @webhook POST newPet
      def new_pet_webhook
      end
    RUBY
    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Docstrings::Parser.parse(tokens, ir)

    assert_empty ir.openapi_spec['paths']

    op = ir.openapi_spec['webhooks']['newPet']['post']
    assert_equal '#/components/schemas/Pet', op['requestBody']['content']['application/json']['schema']['$ref']
    assert_equal 'Return a 200 status to indicate that the data was received successfully',
                 op['responses']['200']['description']

    out = Cdd::Routes::Emitter.emit(ir)
    assert_match(%r{@request_body \[Pet\] application/json Information about a new pet}, out)
    assert_match(/@response 200 Return a 200 status to indicate that the data was received successfully/, out)
  end
end
