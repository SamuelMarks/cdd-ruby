# frozen_string_literal: true

require 'json'

# Core namespace for the CDD Ruby compiler and OpenAPI toolchain.
module Cdd
  # Module for generating and parsing OpenAPI JSON documentation snippets.
  module DocsJson
    # Parser for extracting OpenAPI path and operation metadata from docs_json structures.
    class Parser
      # Parses a docs_json payload (or Ripper token stream containing a JSON payload) into the IR.
      #
      # @param tokens [Array, String, Hash] Ripper tokens, JSON string, or parsed Hash of docs_json
      # @param ir [Cdd::IR] Intermediate Representation to populate
      # @return [Cdd::IR] the updated Intermediate Representation
      def self.parse(tokens, ir)
        payload = extract_payload(tokens)
        return ir unless payload.is_a?(Hash)

        parse_endpoints(payload['endpoints'], ir) if payload['endpoints'].is_a?(Hash)
        parse_workflows(payload['workflows'], ir) if payload['workflows'].is_a?(Hash)
        ir
      end

      # Parses `endpoints` snippets from a docs_json payload into `ir.openapi_spec`.
      #
      # @param endpoints [Hash] endpoints map
      # @param ir [Cdd::IR] Intermediate Representation
      # @return [void]
      def self.parse_endpoints(endpoints, ir)
        ir.openapi_spec['paths'] ||= {}
        endpoints.each do |path, methods|
          next unless methods.is_a?(Hash)

          ir.openapi_spec['paths'][path] ||= {}
          methods.each do |method, snippet|
            op = { 'responses' => { '200' => { 'description' => 'OK' } } }
            if snippet.is_a?(String) && snippet =~ /client\.([a-zA-Z0-9_]+)\s*\(/
              op['operationId'] = ::Regexp.last_match(1)
            end
            ir.openapi_spec['paths'][path][method.downcase] = op
          end
        end
      end

      # Parses `workflows` snippets from a docs_json payload into `ir.arazzo_spec`.
      #
      # @param workflows [Hash] workflows map (`workflowId => snippet`)
      # @param ir [Cdd::IR] Intermediate Representation
      # @return [void]
      def self.parse_workflows(workflows, ir)
        ir.arazzo_spec['workflows'] ||= []
        workflows.each_key do |wf_id|
          ir.arazzo_spec['workflows'] << { 'workflowId' => wf_id, 'steps' => [] }
          ir.workflows |= [wf_id]
        end
      end

      # Extracts a parsed Hash from a Hash, JSON string, or Ripper token array.
      #
      # @param source [Array, String, Hash] input source
      # @return [Hash, nil] parsed Hash or nil if not valid JSON
      def self.extract_payload(source)
        return source if source.is_a?(Hash)

        raw = if source.is_a?(String)
                source
              elsif source.is_a?(Array)
                source.map { |t| t.is_a?(Array) ? t[2].to_s : t.to_s }.join
              else
                return nil
              end
        return nil if raw.strip.empty?

        JSON.parse(raw)
      rescue JSON::ParserError
        nil
      end
    end
  end
end
