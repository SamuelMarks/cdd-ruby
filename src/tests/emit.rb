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
        paths.each do |path, path_data|
          next if path_data["$ref"]
          path_data.each do |method, op|
            next if method == "summary" || method == "description" || method == "servers" || method == "parameters"
            
            op_id = op["operationId"] || "#{method}_#{path.gsub(/[^a-zA-Z0-9]/, '_').gsub(/_+/, '_').sub(/^_/, '').sub(/_$/, '')}"
            
            out += "  # @api_test #{method.upcase} #{path}\n"
            out += "  def test_#{op_id}\n"
            out += "    # TODO: write test for #{method.upcase} #{path}\n"
            out += "    assert true\n"
            out += "  end\n\n"
          end
        end
        out += "end\n\n"
        out
      end
    end
  end
end
