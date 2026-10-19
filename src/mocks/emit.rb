# frozen_string_literal: true

require 'json'

# Core namespace for the CDD Ruby compiler and OpenAPI toolchain.
module Cdd
  # Module for parsing and emitting OpenAPI example mock comments.
  module Mocks
    # Emitter for generating `@mock` and `@example_external` comment blocks from the IR.
    class Emitter
      # Emits mocks from the IR as a single concatenated string.
      #
      # @param ir [Cdd::IR] Intermediate Representation
      # @return [String] generated mock comments string
      def self.emit(ir)
        emit_multiple(ir).values.join("\n")
      end

      # Emits mocks from the IR as a map of filename => content.
      #
      # @param ir [Cdd::IR] Intermediate Representation
      # @return [Hash{String => String}] generated mock files (`filename => content`)
      def self.emit_multiple(ir)
        files = {}
        ir.typed_examples.each do |ex|
          schema = ex.schema_ref || 'Object'
          file_name = "#{schema.downcase.gsub(/[^a-z0-9]/, '_')}_mock.rb"
          files[file_name] ||= ''

          if ex.external_value
            files[file_name] += "# @example_external [#{schema}] #{ex.name} #{ex.external_value}\n\n"
          else
            files[file_name] += "# @mock [#{schema}] #{ex.name}\n"
            JSON.pretty_generate(ex.value).each_line { |line| files[file_name] += "# #{line}" }
            files[file_name] += "\n\n"
          end
        end
        files
      end
    end
  end
end
