# frozen_string_literal: true

# Core namespace for the CDD Ruby compiler and OpenAPI toolchain.
module Cdd
  # Module for parsing and emitting OpenAPI docstring annotations.
  module Docstrings
    # Emits YARD/OpenAPI docstring comments for an Intermediate Representation.
    class Emitter
      # Emits summary docstring annotations for paths and schemas in the IR.
      #
      # @param ir [Cdd::IR] Intermediate Representation
      # @return [String] formatted docstring summary lines
      def self.emit(ir)
        lines = []
        schemas = ir.openapi_spec.dig('components', 'schemas') || {}
        schemas.each do |name, schema|
          desc = schema.is_a?(Hash) && schema['description'] ? " #{schema['description']}" : ''
          lines << "# @schema #{name}#{desc}"
        end

        paths = ir.openapi_spec['paths'] || {}
        paths.each do |path, methods|
          next unless methods.is_a?(Hash)

          methods.each do |method, details|
            next if method.start_with?('x-') || %w[$ref summary description parameters servers].include?(method)

            lines << "# @summary #{details['summary']}" if details.is_a?(Hash) && details['summary']
            lines << "# @route #{method.upcase} #{path}"
          end
        end

        return '' if lines.empty?

        "#{lines.join("\n")}\n"
      end
    end
  end
end
