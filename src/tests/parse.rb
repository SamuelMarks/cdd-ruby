# frozen_string_literal: true

# Documentation for Cdd
module Cdd
  # Module for tests handling
  module Tests
    # Parser for tests
    class Parser
      # Parses tests from tokens and adds to ir
      # @param tokens [Array] tokens array
      # @param ir [Cdd::IR] Intermediate Representation
      def self.parse(tokens, ir)
        tokens.each do |token|
          if token[1] == :on_comment
            if token[2] =~ /#\s*@api_test\s+([A-Z]+)\s+(\S+)/
              method = $1.downcase
              path = $2
              ir.openapi_spec["paths"] ||= {}
              ir.openapi_spec["paths"][path] ||= {}
              ir.openapi_spec["paths"][path][method] ||= {
                "responses" => { "200" => { "description" => "OK" } }
              }
            end
          end
        end
      end
    end
  end
end
