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
        out = ""
        paths = ir.openapi_spec["paths"] || {}
        return out if paths.empty?

        out += "class ApiClientTest < Minitest::Test\n"
        out += "  require 'ostruct'\n\n"
        paths.each do |path, path_data|
          next if path_data["$ref"]
          path_data.each do |method, op|
            next if ["summary", "description", "servers", "parameters"].include?(method)
            
            op_id = op["operationId"] || "#{method}_#{path.gsub(/[^a-zA-Z0-9]/, '_').gsub(/_+/, '_').sub(/^_/, '').sub(/_$/, '')}"
            
            out += "  # @api_test #{method.upcase} #{path}\n"
            out += "  def test_#{op_id}\n"
            out += "    client = ClientSdk.new\n"
            
            params = []
            if op["parameters"]
              op["parameters"].each do |param|
                val = param.dig("schema", "type") == "integer" ? "1" : "'test_#{param['name']}'"
                params << "#{param['name']}: #{val}"
              end
            end
            
            has_body = false
            if op["requestBody"]
              has_body = true
              params << "body: { id: 1 }"
            end
            
            params_str = params.empty? ? "" : "{ #{params.join(', ')} }"
            
            success_code = "200"
            if op["responses"]
              success_code = op["responses"].keys.find { |k| k.to_i >= 200 && k.to_i < 300 } || "200"
            end
            
            out += "    mock_http = Object.new\n"
            out += "    def mock_http.request(req)\n"
            if has_body
              out += "      raise 'Missing request body' if req.body.nil? || req.body.empty?\n"
            else
              out += "      raise 'Unexpected request body' if req.body && !req.body.empty?\n"
            end
            out += "      raise 'Wrong HTTP method' unless req.method == '#{method.upcase}'\n"
            out += "      OpenStruct.new(body: '{\"status\": #{success_code}}', code: '#{success_code}')\n"
            out += "    end\n\n"
            
            out += "    Net::HTTP.stub(:start, ->(host, port, &block) { block.call(mock_http) }) do\n"
            out += "      res = client.#{op_id}(#{params_str})\n"
            out += "      refute_nil res\n"
            out += "      assert_equal #{success_code}, res['status'] if res.is_a?(Hash)\n"
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
