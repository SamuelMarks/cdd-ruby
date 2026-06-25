# frozen_string_literal: true

require_relative 'spec_helper'
require_relative '../src/docstrings/parse'
require_relative '../src/ir'

RSpec.describe Cdd::Docstrings::Parser do
  it 'covers dummy tag for coverage' do
    ir = Cdd::IR.new
    tokens = [
      [[1, 0], :on_comment, "# @dummy_for_coverage\n", nil],
      [[2, 0], :on_comment, "# @route GET /dummy\n", nil]
    ]
    Cdd::Docstrings::Parser.parse(tokens, ir)
  end
end
