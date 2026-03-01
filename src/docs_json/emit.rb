# frozen_string_literal: true

require 'json'

# Documentation for Cdd
module Cdd
  # Module for docs_json handling
  module DocsJson
    # Emitter for docs_json
    class Emitter
      # Emits docs_json from an OpenAPI specification file
      # @param filepath [String] OpenAPI spec filepath
      # @param no_imports [Boolean] whether to omit imports
      # @param no_wrapping [Boolean] whether to omit wrapping
      # @return [String] generated JSON output conforming to doc schema
      def self.emit(filepath, no_imports: false, no_wrapping: false)
        spec = JSON.parse(File.read(filepath))
        operations = []

        (spec["paths"] || {}).each do |path, ops|
          ops.each do |method, op_details|
            next if method.start_with?("x-")
            
            op_id = op_details["operationId"] || "#{method}_#{path.gsub(/[^a-zA-Z0-9]/, '_')}"
            
            code = {}
            code["imports"] = "require 'net/http'
require 'json'" unless no_imports
            code["wrapper_start"] = "def call_#{op_id}
" unless no_wrapping
            
            # Very basic Ruby net/http snippet representing the call
            code["snippet"] = "  uri = URI('https://api.example.com#{path}')
  response = Net::HTTP.#{method.downcase}(uri)
  puts response.body"
            
            code["wrapper_end"] = "end" unless no_wrapping
            
            operations << {
              "method" => method.upcase,
              "path" => path,
              "operationId" => op_id,
              "code" => code
            }
          end
        end

        output = [
          {
            "language" => "ruby",
            "operations" => operations
          }
        ]
        JSON.pretty_generate(output)
      end
    end
  end
end
