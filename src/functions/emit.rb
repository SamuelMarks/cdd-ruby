# frozen_string_literal: true

# Documentation for Cdd
module Cdd
  # Documentation for Functions
  module Functions
    # Emits functions from IR
    class Emitter
      # Emits ruby functions (API Client)
      # @param ir [Cdd::IR]
      # @return [String]
      def self.emit(ir)
        out = ''
        paths = ir.openapi_spec['paths'] || {}
        return out if paths.empty?

        out += "class ApiClient\n"
        paths.each do |path, path_data|
          next if path_data['$ref']

          path_data.each do |method, op|
            next if %w[summary description servers parameters].include?(method)

            op_id = op['operationId'] || "#{method}_#{path.gsub(/[^a-zA-Z0-9]/, '_').gsub(/_+/, '_').sub(/^_/, '').sub(
              /_$/, ''
            )}"

            out += "  # @api_client #{method.upcase} #{path}\n"
            out += "  # summary: #{op['summary']}\n" if op['summary']

            params = []
            op['parameters']&.each do |p|
              next if p['$ref']

              params << "#{p['name']}: nil"
            end

            params << 'body: nil' if op['requestBody']

            params_str = params.empty? ? '' : "(#{params.join(', ')})"

            out += "  def #{op_id}#{params_str}\n"
            out += "    # TODO: implement client logic\n"
            out += "    Net::HTTP.#{method}(URI(\"http://localhost#{path}\"))\n"
            out += "  end\n\n"
          end
        end
        out += "end\n\n"
        out
      end
    end
  end
end
