# frozen_string_literal: true

# Core namespace for the CDD Ruby compiler and OpenAPI toolchain.
module Cdd
  # Module for parsing and emitting top-level OpenAPI specification metadata.
  module Openapi
    # Emitter for generating `@api_*` docstring tags from the IR.
    class Emitter
      # Emits top-level OpenAPI metadata docstring tags from the IR.
      #
      # @param ir [Cdd::IR] Intermediate Representation
      # @return [String] generated `@api_*` docstring lines
      def self.emit(ir)
        spec = ir.openapi_spec
        info = spec['info'] || {}
        out = "# @api_title #{info['title'] || 'Generated API'}\n"
        out += "# @api_version #{info['version'] || '0.0.4'}\n"
        out += "# @swagger_version #{spec['swagger']}\n" if spec['swagger']
        out += "# @api_description #{info['description']}\n" if info['description']
        out += "# @api_self #{spec['$self']}\n" if spec['$self']
        out += "# @api_jsonSchemaDialect #{spec['jsonSchemaDialect']}\n" if spec['jsonSchemaDialect']
        out += emit_servers_and_tags(spec)
        out + emit_docs_and_webhooks(spec)
      end

      # Emits `@api_server` and `@api_tag` docstring lines.
      #
      # @param spec [Hash] OpenAPI specification hash
      # @return [String] formatted server and tag lines
      def self.emit_servers_and_tags(spec)
        out = ''
        spec['servers']&.each do |server|
          desc = server['description'] ? " #{server['description']}" : ''
          out += "# @api_server #{server['url']}#{desc}\n"
        end
        spec['tags']&.each do |tag|
          desc = tag['description'] ? " #{tag['description']}" : ''
          out += "# @api_tag #{tag['name']}#{desc}\n"
        end
        out
      end

      # Emits `@api_externalDocs` and `@api_webhook` docstring lines.
      #
      # @param spec [Hash] OpenAPI specification hash
      # @return [String] formatted externalDocs and webhook lines
      def self.emit_docs_and_webhooks(spec)
        out = ''
        if spec['externalDocs']
          ed = spec['externalDocs']
          desc = ed['description'] ? " #{ed['description']}" : ''
          out += "# @api_externalDocs #{ed['url']}#{desc}\n"
        end
        spec['webhooks']&.each do |name, operations|
          operations.each_key { |method| out += "# @api_webhook #{name} #{method.upcase}\n" }
        end
        "#{out}\n"
      end
    end
  end
end
