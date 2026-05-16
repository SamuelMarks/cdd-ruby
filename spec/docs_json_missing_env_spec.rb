# frozen_string_literal: true

require_relative 'spec_helper'

class DocsJsonMissingEnvTest < Minitest::Test
  def test_docs_json_emit_no_net_http
    original_net = Object.send(:remove_const, :Net) if defined?(Net)
    begin
      assert_raises(RuntimeError) do
        Cdd::DocsJson::Emitter.emit('http://example.com/api.json')
      end
    ensure
      Object.const_set(:Net, original_net) if original_net
    end
  end
end
