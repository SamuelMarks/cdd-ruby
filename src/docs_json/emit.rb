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
      # Default Ruby `require` statements for generated documentation snippets.
      IMPORTS_SNIPPET = "require 'json'\nrequire 'my_api_client'"

      # Opening `def main` and client initialization lines for wrapped snippets.
      WRAPPER_START_SNIPPET = "def main\n  client = MyApiClient.new('https://api.example.com')"

      # Closing `end` and script entrypoint guard for wrapped snippets.
      WRAPPER_END_SNIPPET = "end\n\nmain if __FILE__ == $0"

      # Emits `docs_json` from an OpenAPI specification file or URL.
      #
      # @param filepath [String] OpenAPI spec filepath or URL
      # @param no_imports [Boolean] whether to omit `require` statements
      # @param no_wrapping [Boolean] whether to omit `def main` wrapping
      # @return [String] generated JSON output conforming to the docs schema
      # @raise [Cdd::UnsupportedEnvironmentError] when fetching remote URLs without `Net::HTTP` support
      def self.emit(filepath, no_imports: false, no_wrapping: false)
        spec = load_spec(filepath)
        result = {}
        result['imports'] = IMPORTS_SNIPPET unless no_imports
        result['wrapper_start'] = WRAPPER_START_SNIPPET unless no_wrapping
        result['wrapper_end'] = WRAPPER_END_SNIPPET unless no_wrapping
        result['endpoints'] = build_collection_snippets(spec['paths'], no_imports: no_imports, no_wrapping: no_wrapping)

        webhooks = build_collection_snippets(spec['webhooks'], no_imports: no_imports, no_wrapping: no_wrapping)
        result['webhooks'] = webhooks unless webhooks.empty?

        if spec['workflows'].is_a?(Array) && spec['workflows'].any?
          result['workflows'] = spec['workflows'].to_h do |wf|
            wf_id = wf['workflowId']
            [wf_id, format_operation_snippet(wf_id, no_imports: no_imports, no_wrapping: no_wrapping)]
          end
        end
        JSON.pretty_generate(result)
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

      # Builds a map of path or webhook name => HTTP method snippet objects.
      #
      # @param collection [Hash, nil] OpenAPI `paths` or `webhooks` map
      # @param no_imports [Boolean] omit imports flag
      # @param no_wrapping [Boolean] omit wrapping flag
      # @return [Hash{String => Hash{String => Hash{String => String}}}] nested snippet map
      def self.build_collection_snippets(collection, no_imports:, no_wrapping:)
        out = {}
        (collection || {}).each do |path, ops|
          path_map = build_path_snippets(path, ops, no_imports: no_imports, no_wrapping: no_wrapping)
          out[path] = path_map unless path_map.empty?
        end
        out
      end

      # Builds a map of HTTP method => structured code snippet object for a single path or webhook entry.
      #
      # @param path [String] OpenAPI path or webhook name
      # @param ops [Hash] path operations map
      # @param no_imports [Boolean] omit imports flag
      # @param no_wrapping [Boolean] omit wrapping flag
      # @return [Hash{String => Hash{String => String}}] method => structured snippet map
      def self.build_path_snippets(path, ops, no_imports:, no_wrapping:)
        path_map = {}
        ops.each do |method, op_details|
          next if method.start_with?('x-') || %w[summary description parameters servers].include?(method.downcase)

          op_id = Cdd::TokenScanner.operation_id_for(method.downcase, path, op_details)
          args_str = build_operation_args(op_details)
          path_map[method.downcase] = format_operation_snippet(
            op_id, no_imports: no_imports, no_wrapping: no_wrapping, args_str: args_str
          )
        end
        path_map
      end

      # Builds a comma-separated sample keyword arguments string for an OpenAPI operation call.
      #
      # @param op_details [Hash] OpenAPI operation details
      # @return [String] sample keyword arguments string
      def self.build_operation_args(op_details)
        args = (op_details['parameters'] || []).map do |param|
          "#{param['name']}: #{Cdd::TokenScanner.sample_param_value(param)}"
        end
        if op_details['requestBody']
          schema = Cdd::TokenScanner.first_request_body_schema(op_details)
          args << "body: #{Cdd::TokenScanner.sample_body_hash_literal(schema, symbol_keys: true)}"
        end
        args.join(', ')
      end

      # Formats the structured Ruby client invocation snippet object for a single operationId.
      #
      # @param op_id [String] operationId name
      # @param no_imports [Boolean] omit imports flag
      # @param no_wrapping [Boolean] omit wrapping flag
      # @param args_str [String] formatted sample argument list
      # @return [Hash{String => String}] structured Ruby snippet object
      def self.format_operation_snippet(op_id, no_imports:, no_wrapping:, args_str: '')
        raw_snippet = "response = client.#{op_id}(#{args_str})\nputs response.inspect"
        indent = no_wrapping ? '' : '  '
        call_lines = "#{indent}response = client.#{op_id}(#{args_str})\n#{indent}puts response.inspect"
        entry = {}
        entry['imports'] = IMPORTS_SNIPPET unless no_imports
        entry['wrapper_start'] = WRAPPER_START_SNIPPET unless no_wrapping
        entry['snippet'] = raw_snippet
        entry['wrapper_end'] = WRAPPER_END_SNIPPET unless no_wrapping

        full_parts = []
        full_parts.push(IMPORTS_SNIPPET, '') unless no_imports
        full_parts.push(WRAPPER_START_SNIPPET) unless no_wrapping
        full_parts.push(call_lines)
        full_parts.push(WRAPPER_END_SNIPPET) unless no_wrapping
        entry['code'] = full_parts.join("\n")
        entry
      end

      class << self
        alias generate emit
      end
    end

    # Alias for `Cdd::DocsJson::Emitter`.
    Emit = Emitter
  end
end
