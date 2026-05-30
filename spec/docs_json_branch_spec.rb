# frozen_string_literal: true

require_relative 'spec_helper'
require 'tempfile'

class DocsJsonBranchTest < Minitest::Test
  def test_docs_json_emit_branches
    openapi = {
      'openapi' => '3.0.0',
      'paths' => {
        '/test' => {
          'get' => {
            'operationId' => 'op',
            'summary' => 's'
          }
        }
      }
    }

    file = Tempfile.new(['openapi', '.json'])
    file.write(openapi.to_json)
    file.close

    out = Cdd::DocsJson::Emitter.emit(file.path, no_imports: true, no_wrapping: true)
    assert_match(/response = client\.op/, out)
    refute_match(/require 'json'/, out)

    file.unlink
  end

  def test_docs_json_emit_branches2
    openapi = {
      'openapi' => '3.0.0',
      'paths' => {
        '/test' => {
          'x-test' => {},
          'parameters' => [],
          'post' => {}
        },
        '/empty' => {}
      }
    }

    file = Tempfile.new(['openapi', '.json'])
    file.write(openapi.to_json)
    file.close

    out = Cdd::DocsJson::Emitter.emit(file.path)
    assert_match(/post_test/, out)

    file.unlink
  end
end
