# frozen_string_literal: true

# Core namespace for the CDD Ruby compiler and OpenAPI toolchain.
module Cdd
  # Module for parsing and emitting OpenAPI docstring annotations.
  module Docstrings
    # Emits YARD/OpenAPI docstring comments for an Intermediate Representation.
    class Emitter
      # Non-operation keys in an OpenAPI PathItem object.
      NON_VERB_KEYS = %w[$ref summary description parameters servers].freeze

      # Emits summary docstring annotations for paths and schemas in the IR.
      #
      # @param ir [Cdd::IR] Intermediate Representation
      # @return [String] formatted docstring summary lines
      def self.emit(ir)
        lines = []
        (ir.openapi_spec.dig('components', 'schemas') || {}).each do |name, schema|
          desc = schema.is_a?(Hash) && schema['description'] ? " #{schema['description']}" : ''
          lines << "# @schema #{name}#{desc}"
        end
        (ir.openapi_spec['paths'] || {}).each do |path, methods|
          emit_path_lines(path, methods, lines) if methods.is_a?(Hash)
        end
        lines.empty? ? '' : "#{lines.join("\n")}\n"
      end

      # Appends `@summary` and `@route` lines for a single path item.
      #
      # @param path [String] OpenAPI path string
      # @param methods [Hash] path item operations map
      # @param lines [Array<String>] accumulator array
      # @return [void]
      def self.emit_path_lines(path, methods, lines)
        methods.each do |method, details|
          next if method.start_with?('x-') || NON_VERB_KEYS.include?(method)

          lines << "# @summary #{details['summary']}" if details.is_a?(Hash) && details['summary']
          lines << "# @route #{method.upcase} #{path}"
        end
      end
    end
  end
end
