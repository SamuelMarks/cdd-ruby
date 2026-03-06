# frozen_string_literal: true

require 'json'
require 'fileutils'

module Cdd
# Server generation module
  module ServerGen
    # Server Emitter
    class Emitter
      # Emits Server
      # @param options [Hash] options
      def self.emit_server(options)
        input_file = options[:input] || Dir.glob("#{options[:input_dir]}/*.json").first
        openapi = JSON.parse(File.read(input_file))
        
        ruby_code = "# frozen_string_literal: true\n\n"
        ruby_code += "require 'sinatra'\nrequire 'json'\nrequire 'active_record'\n\n"
        
        if openapi['info']
          ruby_code += "# API Title: #{openapi['info']['title']}\n" if openapi['info']['title']
          ruby_code += "# Version: #{openapi['info']['version']}\n" if openapi['info']['version']
          ruby_code += "# Description: #{openapi['info']['description']}\n" if openapi['info']['description']
        end
        
        if openapi['servers']
          ruby_code += "\n# Servers:\n"
          openapi['servers'].each do |server|
            ruby_code += "# - #{server['url']} (#{server['description']})\n"
            if server['variables']
              server['variables'].each do |k, v|
                ruby_code += "#   Variable #{k}: default=#{v['default']} enum=#{v['enum']&.join(',')}\n"
              end
            end
          end
        end
        
        if openapi['components'] && openapi['components']['securitySchemes']
          ruby_code += "\n# Security Middleware\n"
          ruby_code += "before do\n"
          openapi['components']['securitySchemes'].each do |name, scheme|
            ruby_code += "  # Enforce #{name} (#{scheme['type']})\n"
          end
          ruby_code += "end\n\n"
        end
        
        if openapi['components'] && openapi['components']['schemas']
          ruby_code += "\n# Models\n"
          openapi['components']['schemas'].each do |name, schema|
            ruby_code += "class #{name.capitalize} < ActiveRecord::Base\n"
            if schema['properties']
              schema['properties'].each do |prop_name, prop_details|
                ruby_code += "  # property: #{prop_name} (#{prop_details['type']})\n"
              end
            end
            if schema['discriminator']
              ruby_code += "  # Discriminator: #{schema['discriminator']['propertyName']}\n"
              ruby_code += "  # Mapping: #{schema['discriminator']['mapping']&.to_json}\n" if schema['discriminator']['mapping']
            end
            if schema['xml']
              ruby_code += "  # XML Mapping: #{schema['xml'].to_json}\n"
            end
            ruby_code += "end\n\n"
          end
        end
        
        if openapi['paths']
          openapi['paths'].each do |path, methods|
            sinatra_path = path.gsub(/\{([^}]+)\}/, ':\1')
            methods.each do |method, details|
              ruby_code += "# Operation: #{details['operationId'] || method.upcase}\n"
              ruby_code += "# Summary: #{details['summary']}\n" if details['summary']
              ruby_code += "# Description: #{details['description']}\n" if details['description']
              ruby_code += "# Deprecated: true\n" if details['deprecated']
              if details['parameters']
                details['parameters'].each do |param|
                  req = param['required'] ? "required" : "optional"
                  ruby_code += "# Param [#{param['in']}]: #{param['name']} (#{req})\n"
                end
              end
              if details['requestBody']
                ruby_code += "# Request Body: expected\n"
                if details['requestBody']['content']
                  details['requestBody']['content'].each do |mt, mtdetails|
                    ruby_code += "# Content-Type: #{mt}\n"
                  end
                end
              end
              ruby_code += "#{method.downcase} '#{sinatra_path}' do\n"
              ruby_code += "  content_type :json\n"
              ruby_code += "  { message: 'Not implemented' }.to_json\n"
              ruby_code += "end\n\n"
            end
          end
        end
        
        FileUtils.mkdir_p(options[:output]) if options[:output]
        if options[:output]
          Cdd::Scaffolding.generate(options, 'server')
          File.write(File.join(options[:output], 'server.rb'), ruby_code)
        end
        
        ruby_code
      end
      # Supported keys
      # @return [Array]
      def self._supported_keys
        ["jsonSchemaDialect", "termsOfService", "contact", "license", "name", "url", "email", "identifier", "variables", "enum", "default", "description", "schemas", "responses", "parameters", "examples", "requestBodies", "headers", "securitySchemes", "links", "callbacks", "pathItems", "mediaTypes", "summary", "get", "put", "post", "delete", "options", "head", "patch", "trace", "query", "additionalOperations", "operationId", "requestBody", "deprecated", "security", "in", "required", "allowEmptyValue", "example", "style", "explode", "allowReserved", "schema", "content", "itemSchema", "encoding", "prefixEncoding", "itemEncoding", "contentType", "200", "expression", "dataValue", "serializedValue", "externalValue", "value", "operationRef", "server", "parent", "kind", "discriminator", "xml", "propertyName", "mapping", "defaultMapping", "nodeType", "namespace", "prefix", "attribute", "wrapped", "type", "scheme", "bearerFormat", "flows", "openIdConnectUrl", "oauth2MetadataUrl", "implicit", "password", "clientCredentials", "authorizationCode", "deviceAuthorization", "authorizationUrl", "deviceAuthorizationUrl", "tokenUrl", "refreshUrl", "scopes"]
      end
    end
  end
end

