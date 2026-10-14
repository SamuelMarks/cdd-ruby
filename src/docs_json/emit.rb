# frozen_string_literal: true

# Emitter for generating OpenAPI documentation JSON snippets.
require 'json'
require 'uri'
begin
  require 'net/http'
rescue LoadError
  # Running in a WASM or restricted environment without socket support
end

# Core namespace for the CDD Ruby compiler and OpenAPI toolchain.
module Cdd
  # Module for generating and parsing OpenAPI JSON documentation snippets.
  module DocsJson
    # Emitter for generating OpenAPI endpoint documentation snippets in JSON format.
    class Emitter
      # Emits `docs_json` from an OpenAPI specification file or URL.
      #
      # @param filepath [String] OpenAPI spec filepath or URL
      # @param no_imports [Boolean] whether to omit `require` statements
      # @param no_wrapping [Boolean] whether to omit `def main` wrapping
      # @return [String] generated JSON output conforming to the docs schema
      # @raise [Cdd::UnsupportedEnvironmentError] when fetching remote URLs without `Net::HTTP` support
      def self.emit(filepath, no_imports: false, no_wrapping: false)
        spec = load_spec(filepath)
        endpoints = {}

        (spec['paths'] || {}).each do |path, ops|
          path_map = build_path_snippets(path, ops, no_imports: no_imports, no_wrapping: no_wrapping)
          endpoints[path] = path_map unless path_map.empty?
        end

        JSON.pretty_generate({ 'endpoints' => endpoints })
      end

      # Loads an OpenAPI specification from a local file or remote HTTP(S) URL.
      #
      # @param filepath [String] local path or remote URL
      # @return [Hash] parsed OpenAPI specification
      # @raise [Cdd::UnsupportedEnvironmentError] when fetching remote URLs without `Net::HTTP`
      def self.load_spec(filepath)
        if filepath.start_with?('http://') || filepath.start_with?('https://')
          unless defined?(Net::HTTP)
            raise Cdd::UnsupportedEnvironmentError,
                  'Fetching remote OpenAPI specs is not supported in this environment (WASM/no socket).'
          end

          JSON.parse(Net::HTTP.get(URI(filepath)))
        else
          JSON.parse(File.read(filepath))
        end
      end

      # Builds a map of HTTP method => code snippet for a single path entry.
      #
      # @param path [String] OpenAPI path
      # @param ops [Hash] path operations map
      # @param no_imports [Boolean] omit imports flag
      # @param no_wrapping [Boolean] omit wrapping flag
      # @return [Hash{String => String}] method => snippet map
      def self.build_path_snippets(path, ops, no_imports:, no_wrapping:)
        path_map = {}
        ops.each do |method, op_details|
          next if method.start_with?('x-') || %w[summary description parameters servers].include?(method.downcase)

          op_id = op_details['operationId'] || "#{method.downcase}_#{path.gsub(/[^a-zA-Z0-9]/, '_').sub(/^_/, '')}"
          path_map[method.downcase] = format_operation_snippet(op_id, no_imports: no_imports, no_wrapping: no_wrapping)
        end
        path_map
      end

      # Formats the Ruby client invocation snippet for a single operationId.
      #
      # @param op_id [String] operationId name
      # @param no_imports [Boolean] omit imports flag
      # @param no_wrapping [Boolean] omit wrapping flag
      # @return [String] formatted Ruby snippet
      def self.format_operation_snippet(op_id, no_imports:, no_wrapping:)
        snippet = []
        snippet.push("require 'json'", "require 'my_api_client'", '') unless no_imports
        snippet.push('def main', "  client = MyApiClient.new('https://api.example.com')") unless no_wrapping

        indent = no_wrapping ? '' : '  '
        snippet.push("#{indent}response = client.#{op_id}()", "#{indent}puts response.inspect")
        snippet.push('end', '', 'main if __FILE__ == $0') unless no_wrapping
        snippet.join("\n")
      end
    end
  end
end
