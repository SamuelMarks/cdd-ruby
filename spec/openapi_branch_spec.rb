# frozen_string_literal: true

require_relative 'spec_helper'

class OpenapiBranchTest < Minitest::Test
  def test_openapi_emit_branches
    ir = Cdd::IR.new
    ir.openapi_spec['info'] = {
      'title' => 'T', 'version' => '1', 'description' => 'D'
    }
    ir.openapi_spec['swagger'] = '2.0'
    ir.openapi_spec['$self'] = 'self'
    ir.openapi_spec['jsonSchemaDialect'] = 'http://json-schema.org/draft-04/schema#'
    ir.openapi_spec['servers'] = [
      { 'url' => 'http://test' }
    ]
    ir.openapi_spec['tags'] = [
      { 'name' => 't1' }
    ]

    out = Cdd::Openapi::Emitter.emit(ir)
    assert_match(%r{@api_server http://test$}, out)
    assert_match(/@api_tag t1$/, out)
  end

  def test_openapi_emit_branches2
    ir = Cdd::IR.new
    ir.openapi_spec['externalDocs'] = { 'url' => 'http://ext' }

    out = Cdd::Openapi::Emitter.emit(ir)
    assert_match(%r{@api_externalDocs http://ext$}, out)
  end

  def test_openapi_emit_branches3
    ir = Cdd::IR.new
    ir.openapi_spec['webhooks'] = { 'my_hook' => { 'post' => {} } }

    out = Cdd::Openapi::Emitter.emit(ir)
    assert_match(/@api_webhook my_hook POST/, out)
  end

  def test_openapi_emit_branches4
    ir = Cdd::IR.new
    ir.openapi_spec['externalDocs'] = { 'url' => 'http://ext', 'description' => 'Docs' }

    out = Cdd::Openapi::Emitter.emit(ir)
    assert_match(%r{@api_externalDocs http://ext Docs$}, out)
  end
end
