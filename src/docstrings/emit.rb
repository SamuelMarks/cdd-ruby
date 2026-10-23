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
        ir.typed_schemas.each do |schema|
          desc = schema.description ? " #{schema.description}" : ''
          lines << "# @schema #{schema.name}#{desc}"
        end
        ir.typed_paths.each do |path_item|
          emit_path_lines(path_item, lines)
        end
        lines.empty? ? '' : "#{lines.join("\n")}\n"
      end

      # Appends `@summary`, `@route`, and `@additional_route` lines for a single typed `PathItem`.
      #
      # @param path_item [Cdd::IR::PathItem] typed OpenAPI path item
      # @param lines [Array<String>] accumulator array
      # @return [void]
      def self.emit_path_lines(path_item, lines)
        path_item.operations.each do |method, operation|
          lines << "# @summary #{operation.summary}" if operation.summary
          lines << "# @route #{method.upcase} #{path_item.path}"
        end
        path_item.additional_operations.each do |method, operation|
          lines << "# @summary #{operation.summary}" if operation.summary
          lines << "# @additional_route #{method.upcase} #{path_item.path}"
        end
      end
    end
  end
end
