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
        paths = ir.openapi_spec['paths'] || {}
        return '' if paths.empty?

        out = "class ApiClient\n"
        paths.each do |path, path_data|
          next if path_data['$ref']

          path_data.each do |method, op|
            next if %w[summary description servers parameters].include?(method)

            out += emit_client_method(path, method, op)
          end
        end
        "#{out}end\n\n"
      end

      # Emits a single `def <op_id>` method inside `ApiClient`.
      #
      # @param path [String] endpoint path
      # @param method [String] HTTP verb
      # @param op [Hash] OpenAPI operation hash
      # @return [String] Ruby method code
      def self.emit_client_method(path, method, op)
        op_id = op['operationId'] ||
                "#{method}_#{path.gsub(/[^a-zA-Z0-9]/, '_').gsub(/_+/, '_').sub(/^_/, '').sub(/_$/, '')}"
        out = "  # @api_client #{method.upcase} #{path}\n"
        out += "  # summary: #{op['summary']}\n" if op['summary']

        params = []
        op['parameters']&.each do |param|
          next if param['$ref']

          params << "#{param['name']}: nil"
        end
        params << 'body: nil' if op['requestBody']
        params_str = params.empty? ? '' : "(#{params.join(', ')})"

        "#{out}  def #{op_id}#{params_str}\n    # TODO: implement client logic\n    " \
          "Net::HTTP.#{method}(URI(\"http://localhost#{path}\"))\n  end\n\n"
      end
    end
  end
end
