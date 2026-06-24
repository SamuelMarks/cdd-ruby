# frozen_string_literal: true

require 'json'

# Documentation for Cdd
module Cdd
  # Module for mocks handling
  module Mocks
    # Emitter for mocks
    class Emitter
      # Emits mocks from ir as monolithic string
      # @param ir [Cdd::IR] Intermediate Representation
      # @return [String] generated output
      def self.emit(ir)
        files = emit_multiple(ir)
        files.values.join("\n")
      end

      # Emits mocks from ir as multiple files
      # @param ir [Cdd::IR] Intermediate Representation
      # @return [Hash<String, String>] generated files (filename => content)
      def self.emit_multiple(ir)
        files = {}
        examples = ir.openapi_spec.dig('components', 'examples') || {}
        examples.each do |name, ex|
          schema = ex['summary'].to_s.split('for ').last || 'Object'
          schema_name = schema.downcase.gsub(/[^a-z0-9]/, '_')
          file_name = "#{schema_name}_mock.rb"
          files[file_name] ||= ''

          if ex['externalValue']
            files[file_name] += "# @example_external [#{schema}] #{name} #{ex['externalValue']}\n\n"
          else
            files[file_name] += "# @mock [#{schema}] #{name}\n"
            json = JSON.pretty_generate(ex['value'])
            json.each_line do |line|
              files[file_name] += "# #{line}"
            end
            files[file_name] += "\n\n"
          end
        end
        files
      end
    end
  end
end
