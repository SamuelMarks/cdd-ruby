# frozen_string_literal: true

require_relative '../token_scanner'

# Core namespace for the CDD Ruby compiler and OpenAPI toolchain.
module Cdd
  # Server generation and parsing module.
  module ServerGen
    # Parser for extracting server routes from Ripper tokens.
    class Parser
      # Parses server routes from tokens and populates the IR.
      #
      # @param tokens [Array<Array>] Ripper lexed token array
      # @param ir [Cdd::IR] Intermediate Representation
      # @return [void]
      def self.parse(tokens, ir)
        Cdd::TokenScanner.parse_sinatra_routes(tokens, ir)
      end
    end
  end
end
