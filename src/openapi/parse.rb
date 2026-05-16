# frozen_string_literal: true

# Documentation for Cdd
module Cdd
  # Module for openapi handling
  module Openapi
    # Parser for openapi metadata
    class Parser
      # Parses openapi info from tokens and adds to ir
      # @param tokens [Array] tokens array
      # @param ir [Cdd::IR] Intermediate Representation
      def self.parse(tokens, ir)
        tokens.each do |token|
          next unless token[1] == :on_comment

          comment = token[2]
          case comment
          when /#\s*@api_title\s+(.*)/
            ir.openapi_spec['info'] ||= {}
            ir.openapi_spec['info']['title'] = ::Regexp.last_match(1).strip
          when /#\s*@api_version\s+(.*)/
            ir.openapi_spec['info'] ||= {}
            ir.openapi_spec['info']['version'] = ::Regexp.last_match(1).strip
          when /#\s*@swagger_version\s+(.*)/
            ir.openapi_spec['swagger'] = ::Regexp.last_match(1).strip
            ir.openapi_spec.delete('openapi')
          when /#\s*@api_description\s+(.*)/
            ir.openapi_spec['info'] ||= {}
            ir.openapi_spec['info']['description'] = ::Regexp.last_match(1).strip
          when /#\s*@api_self\s+(.*)/
            ir.openapi_spec['$self'] = ::Regexp.last_match(1).strip
          when /#\s*@api_jsonSchemaDialect\s+(.*)/
            ir.openapi_spec['jsonSchemaDialect'] = ::Regexp.last_match(1).strip
          when /#\s*@api_server\s+(\S+)(?:\s+(.*))?/
            ir.openapi_spec['servers'] ||= []
            desc = ::Regexp.last_match(2) && !::Regexp.last_match(2).empty? ? ::Regexp.last_match(2).strip : nil
            server_hash = { 'url' => ::Regexp.last_match(1).strip }
            server_hash['description'] = desc if desc
            ir.openapi_spec['servers'] << server_hash
          when /#\s*@api_tag\s+(\S+)(?:\s+(.*))?/
            ir.openapi_spec['tags'] ||= []
            desc = ::Regexp.last_match(2) && !::Regexp.last_match(2).empty? ? ::Regexp.last_match(2).strip : nil
            tag_hash = { 'name' => ::Regexp.last_match(1).strip }
            tag_hash['description'] = desc if desc
            ir.openapi_spec['tags'] << tag_hash
          when /#\s*@api_externalDocs\s+(\S+)(?:\s+(.*))?/
            desc = ::Regexp.last_match(2) && !::Regexp.last_match(2).empty? ? ::Regexp.last_match(2).strip : nil
            ed_hash = { 'url' => ::Regexp.last_match(1).strip }
            ed_hash['description'] = desc if desc
            ir.openapi_spec['externalDocs'] = ed_hash
          when /#\s*@api_webhook\s+(\S+)\s+(GET|POST|PUT|DELETE|PATCH|OPTIONS|HEAD|TRACE|QUERY)/i
            name = ::Regexp.last_match(1).strip
            method = ::Regexp.last_match(2).downcase
            ir.openapi_spec['webhooks'] ||= {}
            ir.openapi_spec['webhooks'][name] ||= {}
            ir.openapi_spec['webhooks'][name][method] = { 'responses' => { '200' => { 'description' => 'OK' } } }
          end
        end
      end
    end
  end
end
