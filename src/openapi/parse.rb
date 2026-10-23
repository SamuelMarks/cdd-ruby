# frozen_string_literal: true

# Core namespace for the CDD Ruby compiler and OpenAPI toolchain.
module Cdd
  # Module for parsing and emitting top-level OpenAPI specification metadata.
  module Openapi
    # Parser for extracting `@api_*` metadata docstring tags from Ripper tokens.
    class Parser
      # Parses `@api_*` comments from tokens and populates the IR.
      #
      # @param tokens [Array<Array>] Ripper lexed token array
      # @param ir [Cdd::IR] Intermediate Representation
      # @return [void]
      def self.parse(tokens, ir)
        tokens.each do |token|
          next unless token[1] == :on_comment

          parse_api_comment(token[2], ir.openapi_spec)
        end
      end

      # Parses a single `@api_*` comment line into the OpenAPI specification hash.
      #
      # @param comment [String] raw comment text
      # @param spec [Hash] OpenAPI specification hash
      # @return [void]
      def self.parse_api_comment(comment, spec)
        case comment
        when /#\s*@api_title\s+(.*)/
          (spec['info'] ||= {})['title'] = ::Regexp.last_match(1).strip
        when /#\s*@api_version\s+(.*)/
          (spec['info'] ||= {})['version'] = ::Regexp.last_match(1).strip
        when /#\s*@swagger_version\s+(.*)/
          spec['swagger'] = ::Regexp.last_match(1).strip
          spec.delete('openapi')
        when /#\s*@api_description\s+(.*)/
          (spec['info'] ||= {})['description'] = ::Regexp.last_match(1).strip
        when /#\s*@api_self\s+(.*)/
          spec['$self'] = ::Regexp.last_match(1).strip
        when /#\s*@api_jsonSchemaDialect\s+(.*)/
          spec['jsonSchemaDialect'] = ::Regexp.last_match(1).strip
        else
          parse_api_collection_comment(comment, spec)
        end
      end

      # Parses `@api_produces`, `@api_server`, `@api_tag`, `@api_externalDocs`, and `@api_webhook` comments.
      #
      # @param comment [String] raw comment text
      # @param spec [Hash] OpenAPI specification hash
      # @return [void]
      def self.parse_api_collection_comment(comment, spec)
        case comment
        when /#\s*@api_produces\s+(.*)/
          spec['produces'] = ::Regexp.last_match(1).split(/\s*,\s*/).reject(&:empty?)
        when /#\s*@api_server\s+(\S+)(?:\s+(.*))?/
          (spec['servers'] ||= []) << build_described_entry('url', ::Regexp.last_match(1), ::Regexp.last_match(2))
        when /#\s*@api_tag\s+(\S+)(?:\s+(.*))?/
          (spec['tags'] ||= []) << build_described_entry('name', ::Regexp.last_match(1), ::Regexp.last_match(2))
        when /#\s*@api_externalDocs\s+(\S+)(?:\s+(.*))?/
          spec['externalDocs'] = build_described_entry('url', ::Regexp.last_match(1), ::Regexp.last_match(2))
        when /#\s*@api_webhook\s+(\S+)\s+(GET|POST|PUT|DELETE|PATCH|OPTIONS|HEAD|TRACE|QUERY)/i
          name = ::Regexp.last_match(1).strip
          method = ::Regexp.last_match(2).downcase
          ((spec['webhooks'] ||= {})[name] ||= {})[method] = { 'responses' => { '200' => { 'description' => 'OK' } } }
        end
      end

      # Builds a hash with `primary_key => val` and optional `'description'`.
      #
      # @param primary_key [String] `'url'` or `'name'`
      # @param raw_val [String] primary value
      # @param raw_desc [String, nil] optional description text
      # @return [Hash{String => String}] constructed entry hash
      def self.build_described_entry(primary_key, raw_val, raw_desc)
        entry = { primary_key => raw_val.strip }
        desc = raw_desc.to_s.strip
        entry['description'] = desc unless desc.empty?
        entry
      end
    end
  end
end
