require_relative 'spec_helper'

class CoverageTest < Minitest::Test
  def test_descriptions_and_opts
    code = <<~RUBY
      # @security_scheme api_key apiKey description:Api key auth
      # @schema Item description:An item
      # @component_param filter [integer] in:query description:Filter items
      # @request_body [Item] application/json description:The body
      # @component_response MyResp [Item] application/json x-opt:true
      # @component_response EmptyResp x-opt:false
      def dummy
      end
    RUBY
    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Docstrings::Parser.parse(tokens, ir)
  end
  
  def test_emit_refs
    ir = Cdd::IR.new
    ir.openapi_spec["components"]["parameters"] = {
      "refParam" => {
        "name" => "refParam",
        "in" => "query",
        "schema" => { "$ref" => "#/components/schemas/RefParam" }
      }
    }
    
    ir.openapi_spec["paths"]["/ref"] = {
      "get" => {
        "responses" => {
          "200" => {
            "description" => "OK",
            "headers" => {
              "X-Ref" => {
                "schema" => { "$ref" => "#/components/schemas/RefHeader" }
              }
            },
            "links" => {
              "MyLink" => {
                "requestBody" => "$request.body#/id"
              }
            }
          }
        }
      }
    }
    
    out = Cdd::Routes::Emitter.emit(ir)
    assert_match(/@component_param refParam \[RefParam\]/, out)
    assert_match(/@response_header 200 X-Ref \[RefHeader\]/, out)
    assert_match(/@link 200 MyLink requestBody:\$request.body#\/id/, out)
  end

  def test_response_header_desc
    code = <<~RUBY
      # @response_header 200 X-Test [string] description:A test header
      def dummy2
      end
    RUBY
    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Docstrings::Parser.parse(tokens, ir)
  end

  def test_param_desc
    code = <<~RUBY
      # @param q [string] in:query description:The query
      def dummy3
      end
    RUBY
    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Docstrings::Parser.parse(tokens, ir)
  end

  def test_callback_request_body_description
    code = <<~RUBY
      # @callback myCallback {$request.query.callbackUrl} post
      # @callback_request_body [Event] application/json description:An event body
      # @route POST /cb_desc
      def dummy
      end
    RUBY
    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Docstrings::Parser.parse(tokens, ir)
  end

  def test_component_header_options
    code = <<~RUBY
      # @component_header RateLimit [integer] description:Rate limit required:true
      def dummy
      end
    RUBY
    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Docstrings::Parser.parse(tokens, ir)
    
    # Test emit for header with schema $ref
    ir.openapi_spec["components"]["headers"]["X-Test"] = {
      "schema" => { "$ref" => "#/components/schemas/TestSchema" }
    }
    Cdd::Routes::Emitter.emit(ir)
  end

  def test_component_callback_options
    code = <<~RUBY
      # @component_callback MyCallback {$request.query.callbackUrl} post
      # @component_callback_response 200 [Event] application/json description:OK true_val:true
      # @component_callback_response 400 description:Bad false_val:false
      def dummy
      end
    RUBY
    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Docstrings::Parser.parse(tokens, ir)
    Cdd::Routes::Emitter.emit(ir)
  end

  def test_component_link_request_body
    code = <<~RUBY
      # @component_link LinkWithBody requestBody:testBody
      def dummy
      end
    RUBY
    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Docstrings::Parser.parse(tokens, ir)
    Cdd::Routes::Emitter.emit(ir)
  end

  def test_encoding_headers
    code = <<~RUBY
      # @request_body [Profile] multipart/form-data
      # @route POST /enc_head
      def dummy
      end
    RUBY
    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Docstrings::Parser.parse(tokens, ir)
    ir.openapi_spec["paths"]["/enc_head"]["post"]["requestBody"]["content"]["multipart/form-data"]["encoding"] = {
      "profileImage" => {
        "headers" => {
          "X-Rate-Limit" => { "$ref" => "#/components/headers/RateLimit" }
        }
      }
    }
    Cdd::Routes::Emitter.emit(ir)
  end

  def test_request_body_encoding_desc
    code = <<~RUBY
      # @request_body_encoding multipart/form-data profileImage description:A description
      def dummy
      end
    RUBY
    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Docstrings::Parser.parse(tokens, ir)
  end

  def test_component_callback_response_no_pairs
    code = <<~RUBY
      # @component_callback MyCallback {$request.query.callbackUrl} post
      # @component_callback_response 200 Something
      def dummy
      end
    RUBY
    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Docstrings::Parser.parse(tokens, ir)
  end
end
