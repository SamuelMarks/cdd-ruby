# frozen_string_literal: true

require 'json'
require 'uri'
begin
  require 'net/http'
rescue LoadError
  # Running in a WASM or restricted environment without socket support
end

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
        if filepath.start_with?('http://') || filepath.start_with?('https://')
          unless defined?(Net::HTTP)
            raise 'Fetching remote OpenAPI specs is not supported in this environment (WASM/no socket).'
          end

          uri = URI(filepath)
          response = Net::HTTP.get(uri)
          spec = JSON.parse(response)
        else
          spec = JSON.parse(File.read(filepath))
        end

        endpoints = {}

        (spec['paths'] || {}).each do |path, ops|
          path_map = {}
          ops.each do |method, op_details|
            next if method.start_with?('x-') || %w[summary description parameters servers].include?(method.downcase)

            op_id = op_details['operationId'] || "#{method.downcase}_#{path.gsub(/[^a-zA-Z0-9]/, '_').sub(/^_/, '')}"

            snippet = []

            unless no_imports
              snippet << "require 'json'"
              snippet << "require 'my_api_client'"
              snippet << ''
            end

            unless no_wrapping
              snippet << 'def main'
              snippet << "  client = MyApiClient.new('https://api.example.com')"
            end

            indent = no_wrapping ? '' : '  '
            snippet << "#{indent}response = client.#{op_id}()"
            snippet << "#{indent}puts response.inspect"

            unless no_wrapping
              snippet << 'end'
              snippet << ''
              snippet << 'main if __FILE__ == $0'
            end

            path_map[method.downcase] = snippet.join("\n")
          end

          endpoints[path] = path_map unless path_map.empty?
        end

        output = {
          'endpoints' => endpoints
        }
        JSON.pretty_generate(output)
      end
    end
  end
end
