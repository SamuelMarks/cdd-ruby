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
          if token[1] == :on_comment
            comment = token[2]
            if comment =~ /#\s*@api_title\s+(.*)/
              ir.openapi_spec["info"] ||= {}
              ir.openapi_spec["info"]["title"] = $1.strip
            elsif comment =~ /#\s*@api_version\s+(.*)/
              ir.openapi_spec["info"] ||= {}
              ir.openapi_spec["info"]["version"] = $1.strip
            elsif comment =~ /#\s*@api_description\s+(.*)/
              ir.openapi_spec["info"] ||= {}
              ir.openapi_spec["info"]["description"] = $1.strip
            elsif comment =~ /#\s*@api_self\s+(.*)/
              ir.openapi_spec["$self"] = $1.strip
            elsif comment =~ /#\s*@api_jsonSchemaDialect\s+(.*)/
              ir.openapi_spec["jsonSchemaDialect"] = $1.strip
            elsif comment =~ /#\s*@api_server\s+(\S+)(?:\s+(.*))?/
              ir.openapi_spec["servers"] ||= []
              desc = $2 && !$2.empty? ? $2.strip : nil
              server_hash = { "url" => $1.strip }
              server_hash["description"] = desc if desc
              ir.openapi_spec["servers"] << server_hash
            elsif comment =~ /#\s*@api_tag\s+(\S+)(?:\s+(.*))?/
              ir.openapi_spec["tags"] ||= []
              desc = $2 && !$2.empty? ? $2.strip : nil
              tag_hash = { "name" => $1.strip }
              tag_hash["description"] = desc if desc
              ir.openapi_spec["tags"] << tag_hash
            elsif comment =~ /#\s*@api_externalDocs\s+(\S+)(?:\s+(.*))?/
              desc = $2 && !$2.empty? ? $2.strip : nil
              ed_hash = { "url" => $1.strip }
              ed_hash["description"] = desc if desc
              ir.openapi_spec["externalDocs"] = ed_hash
            elsif comment =~ /#\s*@api_webhook\s+(\S+)\s+(GET|POST|PUT|DELETE|PATCH|OPTIONS|HEAD|TRACE|QUERY)/i
              name = $1.strip
              method = $2.downcase
              ir.openapi_spec["webhooks"] ||= {}
              ir.openapi_spec["webhooks"][name] ||= {}
              ir.openapi_spec["webhooks"][name][method] = { "responses" => { "200" => { "description" => "OK" } } }
            end
          end
        end
      end
    end
  end
end
