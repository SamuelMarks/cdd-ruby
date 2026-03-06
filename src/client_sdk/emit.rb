# frozen_string_literal: true

require 'json'
require 'fileutils'

module Cdd
# Client SDK module
  module ClientSdk
    # SDK Emitter
    class Emitter
      # Emits SDK
      # @param options [Hash] options
      def self.emit_sdk(options)
        input_file = options[:input] || Dir.glob("#{options[:input_dir]}/*.json").first
        openapi = JSON.parse(File.read(input_file))
        
        ruby_code = "# frozen_string_literal: true\n\n"
        ruby_code += "require 'net/http'\nrequire 'json'\n\n"
        
        info = openapi['info'] || {}
        ruby_code += "# Auto-generated SDK for #{info['title'] || 'API'}\n"
        ruby_code += "# Version: #{info['version']}\n" if info['version']
        
        if openapi['components'] && openapi['components']['schemas']
          ruby_code += "module Types\n"
          openapi['components']['schemas'].each do |name, schema|
            ruby_code += "  class #{name}\n"
            ruby_code += "    # schema example: #{schema['example']}\n" if schema['example']
            if schema['properties']
              schema['properties'].each do |pname, pdetails|
                ruby_code += "    attr_accessor :#{pname}\n"
              end
            end
            ruby_code += "  end\n"
          end
          ruby_code += "end\n\n"
        end
        
        ruby_code += "class ClientSdk\n"
        
        if openapi['servers']
          ruby_code += "  # Base URL mappings:\n"
          openapi['servers'].each do |server|
            ruby_code += "  # #{server['url']} - #{server['description']}\n"
          end
        end
        
        if openapi['paths']
          openapi['paths'].each do |path, methods|
            methods.each do |method, details|
              operation_id = details['operationId'] || "#{method}_#{path.gsub(/[^a-zA-Z0-9]/, '_')}"
              
              ruby_code += "  # #{details['summary']}\n" if details['summary']
              ruby_code += "  # @param path [String] #{path}\n"
              
              if details['parameters']
                details['parameters'].each do |param|
                  ruby_code += "  # @param #{param['name']} [#{param['in']}]\n"
                  ruby_code += "  #  required: #{param['required']}, allowEmptyValue: #{param['allowEmptyValue']}, style: #{param['style']}, explode: #{param['explode']}, allowReserved: #{param['allowReserved']}, schema: #{param.dig('schema', 'type')}\n"
                end
              end
              
              if details['requestBody']
                req = details['requestBody']['required'] ? "required" : "optional"
                ruby_code += "  # Request Body (#{req}):\n"
                if details['requestBody']['content']
                  details['requestBody']['content'].each do |mt, mtdetails|
                    ruby_code += "  #  #{mt} schema: #{mtdetails.dig('schema', '$ref')}\n"
                    if mtdetails['encoding']
                      mtdetails['encoding'].each do |enc_k, enc_v|
                        ruby_code += "  #  Encoding #{enc_k}: contentType=#{enc_v['contentType']} style=#{enc_v['style']} explode=#{enc_v['explode']} allowReserved=#{enc_v['allowReserved']}\n"
                      end
                    end
                  end
                end
              end
              
              if details['responses']
                details['responses'].each do |status, resp|
                  ruby_code += "  # @return [#{status}] #{resp['description']}\n"
                  if resp['headers']
                    resp['headers'].each do |hname, hdetails|
                      ruby_code += "  #   Header #{hname}: required=#{hdetails['required']}, style=#{hdetails['style']}, explode=#{hdetails['explode']}, schema=#{hdetails.dig('schema', 'type')}\n"
                    end
                  end
                  if resp['links']
                    resp['links'].each do |lname, ldetails|
                      ruby_code += "  #   Link #{lname}: operationRef=#{ldetails['operationRef']}\n"
                    end
                  end
                end
              end
              
              ruby_code += "  def #{operation_id}\n"
              ruby_code += "    # stub for #{method.upcase} #{path}\n"
              ruby_code += "    # Auth Required: #{details['security']&.to_json}\n" if details['security']
              ruby_code += "  end\n\n"
            end
          end
        end
        
        ruby_code += "  # Examples (externalValue)\n"
        if openapi['components'] && openapi['components']['examples']
          openapi['components']['examples'].each do |ename, edetails|
            ruby_code += "  # Example #{ename}: #{edetails['externalValue']}\n" if edetails['externalValue']
          end
        end
        
        ruby_code += "end\n"
        
        FileUtils.mkdir_p(options[:output]) if options[:output]
        if options[:output]
          Cdd::Scaffolding.generate(options, 'sdk')
          File.write(File.join(options[:output], 'sdk.rb'), ruby_code)
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

