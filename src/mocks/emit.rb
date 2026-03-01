# frozen_string_literal: true

require 'json'

# Documentation for Cdd
module Cdd
  # Module for mocks handling
  module Mocks
    # Emitter for mocks
    class Emitter
      # Emits mocks from ir
      # @param ir [Cdd::IR] Intermediate Representation
      # @return [String] generated output
      def self.emit(ir)
        out = ""
        examples = ir.openapi_spec.dig("components", "examples") || {}
        examples.each do |name, ex|
          schema = ex["summary"].to_s.split("for ").last || "Object"
          if ex["externalValue"]
            out += "# @example_external [#{schema}] #{name} #{ex["externalValue"]}\n\n"
          else
            out += "# @mock [#{schema}] #{name}\n"
          json = JSON.pretty_generate(ex["value"])
          json.each_line do |line|
            out += "# #{line}"
          end
            out += "\n\n"
          end
        end
        out
      end
    end
  end
end
