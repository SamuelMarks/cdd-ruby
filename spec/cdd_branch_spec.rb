# frozen_string_literal: true

require_relative 'spec_helper'
require 'tempfile'

class CddBranchTest < Minitest::Test
  def test_emit_with_original_file
    openapi_file = Tempfile.new(['openapi', '.json'])
    openapi_file.write('{}')
    openapi_file.close

    ruby_file = Tempfile.new(['original', '.rb'])
    ruby_file.write('# existing code')
    ruby_file.close

    out = Cdd::Emitter.emit(openapi_file.path, ruby_file.path)
    assert_match(/frozen_string_literal/, out)

    openapi_file.unlink
    ruby_file.unlink
  end
end
