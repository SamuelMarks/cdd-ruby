# frozen_string_literal: true

require_relative '../token_scanner'

# Core namespace for the CDD Ruby compiler and OpenAPI toolchain.
module Cdd
  # Module for parsing and emitting Sinatra route definitions.
  module Routes
    # Parser for extracting Sinatra routes from Ripper tokens.
    class Parser
      # Parses Sinatra routes from tokens and populates the IR.
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
