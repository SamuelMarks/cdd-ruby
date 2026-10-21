# frozen_string_literal: true

# Core namespace for the CDD Ruby compiler and OpenAPI toolchain.
module Cdd
  # Module for parsing and emitting API client functions.
  module Functions
    # Emitter for generating `ApiClient` Ruby methods from an Intermediate Representation.
    class Emitter
      # Emits `ApiClient` Ruby methods from the IR.
      #
      # @param ir [Cdd::IR] Intermediate Representation
      # @return [String] generated `ApiClient` Ruby source code
      def self.emit(ir)
        typed_paths = ir.typed_paths
        return '' if typed_paths.empty?

        out = "class ApiClient\n"
        typed_paths.each do |path_item|
          next if path_item.ref

          path_item.operations.each do |method, op|
            out += emit_client_method(path_item.path, method, op)
          end
        end
        "#{out}end\n\n"
      end

      # Emits a single `def <op_id>` method inside `ApiClient`.
      #
      # @param path [String] endpoint path
      # @param method [String] HTTP verb
      # @param op [Cdd::IR::Operation] typed OpenAPI operation object
      # @return [String] Ruby method code
      def self.emit_client_method(path, method, op)
        op_id = Cdd::TokenScanner.operation_id_for(method, path, { 'operationId' => op.operation_id })
        out = "  # @api_client #{method.upcase} #{path}\n"
        out += "  # summary: #{op.summary}\n" if op.summary

        params = extract_client_method_params(op)
        params_str = params.empty? ? '' : "(#{params.join(', ')})"
        http_const = Cdd::TokenScanner.classify_name(method.downcase)

        "#{out}  def #{op_id}#{params_str}\n    # TODO: implement client logic\n    " \
          "Net::HTTP::#{http_const}.new(URI(\"http://localhost#{path}\"))\n  end\n\n"
      end

      # Extracts keyword parameter declarations for a client operation method.
      #
      # @param op [Cdd::IR::Operation] typed OpenAPI operation object
      # @return [Array<String>] list of `<name>: nil` parameter strings
      def self.extract_client_method_params(op)
        params = op.parameters.filter_map { |param| "#{param.name}: nil" if param.name }
        params << 'body: nil' if op.request_body
        params
      end
    end
  end
end
