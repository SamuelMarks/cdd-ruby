# frozen_string_literal: true

# Documentation for Cdd
module Cdd
  # Module for openapi handling
  module Openapi
    # Emitter for openapi metadata
    class Emitter
      # Emits openapi metadata from ir
      # @param ir [Cdd::IR] Intermediate Representation
      # @return [String] generated output
      def self.emit(ir)
        out = ""
        info = ir.openapi_spec["info"] || {}
        out += "# @api_title #{info['title'] || 'Generated API'}\n"
        out += "# @api_version #{info['version'] || '0.0.1'}\n"
        out += "# @api_description #{info['description']}\n" if info['description']
        
        if ir.openapi_spec["$self"]
          out += "# @api_self #{ir.openapi_spec['$self']}\n"
        end
        
        if ir.openapi_spec["jsonSchemaDialect"]
          out += "# @api_jsonSchemaDialect #{ir.openapi_spec['jsonSchemaDialect']}\n"
        end
        
        if ir.openapi_spec["servers"]
          ir.openapi_spec["servers"].each do |server|
            desc = server["description"] ? " #{server['description']}" : ""
            out += "# @api_server #{server['url']}#{desc}\n"
          end
        end
        
        if ir.openapi_spec["tags"]
          ir.openapi_spec["tags"].each do |tag|
            desc = tag["description"] ? " #{tag['description']}" : ""
            out += "# @api_tag #{tag['name']}#{desc}\n"
          end
        end
        
        if ir.openapi_spec["externalDocs"]
          ed = ir.openapi_spec["externalDocs"]
          desc = ed["description"] ? " #{ed['description']}" : ""
          out += "# @api_externalDocs #{ed['url']}#{desc}\n"
        end
        
        if ir.openapi_spec["webhooks"]
          ir.openapi_spec["webhooks"].each do |name, operations|
            operations.each do |method, op|
              out += "# @api_webhook #{name} #{method.upcase}\n"
            end
          end
        end
        
        out += "\n"
        out
      end
    end
  end
end
