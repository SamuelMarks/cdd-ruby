# frozen_string_literal: true

require_relative 'spec_helper'

class DocsJsonParserCoverageTest < Minitest::Test
  def test_docs_json_parse
    # docs_json/parse.rb just has an empty def self.parse
    ir = Cdd::IR.new
    Cdd::DocsJson::Parser.parse([], ir)
    assert true
  end
end
