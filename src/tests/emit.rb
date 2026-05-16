# frozen_string_literal: true

# Documentation for Cdd
module Cdd
  # Module for tests handling
  module Tests
    # Emitter for tests
    class Emitter
      # Emits tests from ir
      # @param ir [Cdd::IR] Intermediate Representation
      # @return [String] generated output
      def self.emit(ir)
        out = ''
        paths = ir.openapi_spec['paths'] || {}
        return out if paths.empty?

        out += "class ApiClientTest < Minitest::Test\n"
        out += "  require 'ostruct'\n\n"
        paths.each do |path, path_data|
          next if path_data['$ref']

          path_data.each do |method, op|
            next if %w[summary description servers parameters].include?(method)

            op_id = op['operationId'] || "#{method}_#{path.gsub(/[^a-zA-Z0-9]/, '_').gsub(/_+/, '_').sub(/^_/, '').sub(
              /_$/, ''
            )}"

            out += "  # @api_test #{method.upcase} #{path}\n"
            out += "  def test_#{op_id}\n"
            out += "    client = ClientSdk.new('http://localhost:8080/v2')\n"

            params = []
            op['parameters']&.each do |param|
              val = if param.dig('schema',
                                 'type') == 'integer'
                      '1'
                    else
                      (param['name'] == 'status' ? "'available'" : "'test_#{param['name']}'")
                    end
              params << "#{param['name']}: #{val}"
            end

            if op['requestBody']
              params << 'id: 1'
              params << "name: 'test'"
              params << "photoUrls: ['http://example.com']"
              params << "status: 'available'"
            end

            params_str = params.empty? ? '' : "{ #{params.join(', ')} }"

            success_code = '200'
            success_code = op['responses'].keys.find { |k| k.to_i >= 200 && k.to_i < 300 } || '200' if op['responses']

            out += "    begin\n"
            out += "      res = client.#{op_id}(#{params_str})\n"
            out += "      refute_nil res\n"
            out += "      assert_equal '#{success_code}', client.last_response.code\n"
            out += "    rescue Errno::ECONNREFUSED\n"
            out += "      skip 'Petstore server is not available'\n"
            out += "    end\n"
            out += "  end\n\n"
          end
        end
        out += "end\n\n"
        out
      end
    end
  end
end
