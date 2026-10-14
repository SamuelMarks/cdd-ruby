# frozen_string_literal: true

# Core namespace for the CDD Ruby compiler and OpenAPI toolchain.
module Cdd
  # Module for parsing and emitting unit and integration test suites.
  module Tests
    # Parser for extracting `@api_test` route annotations from Ripper tokens.
    class Parser
      # Parses `@api_test` comments from tokens and populates the IR.
      #
      # @param tokens [Array<Array>] Ripper lexed token array
      # @param ir [Cdd::IR] Intermediate Representation
      # @return [void]
      def self.parse(tokens, ir)
        tokens.each do |token|
          next unless (token[1] == :on_comment) && (token[2] =~ /#\s*@api_test\s+([A-Z]+)\s+(\S+)/)

          method = ::Regexp.last_match(1).downcase
          path = ::Regexp.last_match(2)
          ir.openapi_spec['paths'] ||= {}
          ir.openapi_spec['paths'][path] ||= {}
          ir.openapi_spec['paths'][path][method] ||= {
            'responses' => { '200' => { 'description' => 'OK' } }
          }
        end
      end
    end
  end
end
