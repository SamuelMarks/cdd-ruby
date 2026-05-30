# frozen_string_literal: true

require_relative 'spec_helper'

class ClassesBranchTest2 < Minitest::Test
  def test_classes_parse_branches2
    code = <<~RUBY
      # @schema oneOf Ref1,Ref2 unknownPart
      class
    RUBY
    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Classes::Parser.parse(tokens, ir)
  end
end
