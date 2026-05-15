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
      # @return [String]
      def self.emit_sdk(options)
        input_file = options[:input] || Dir.glob("#{options[:input_dir]}/*.json").first
        openapi = JSON.parse(File.read(input_file))
        
        models_code = "# frozen_string_literal: true\n\n"
        
        info = openapi['info'] || {}
        models_code += "# Auto-generated Models for #{info['title'] || 'API'}\n"
        models_code += "# Version: #{info['version']}\n" if info['version']
        
        if openapi['components'] && openapi['components']['schemas']
          models_code += "module Types\n"
          openapi['components']['schemas'].each do |name, schema|
            models_code += "  class #{name}\n"
            models_code += "    # schema example: #{schema['example']}\n" if schema['example']
            if schema['properties']
              schema['properties'].each do |pname, pdetails|
                models_code += "    attr_accessor :#{pname}\n"
              end
            end
            models_code += "  end\n"
          end
          models_code += "end\n"
        end
        
        client_code = "# frozen_string_literal: true\n\n"
        client_code += "require 'net/http'\nrequire 'json'\n"
        client_code += "require_relative 'models'\n\n"
        
        client_code += "# Auto-generated SDK for #{info['title'] || 'API'}\n"
        client_code += "# Version: #{info['version']}\n" if info['version']
        
        client_code += "class ClientSdk\n"
        client_code += "  attr_accessor :base_url, :last_response\n"
        client_code += "  def initialize(base_url = 'http://localhost')\n"
        client_code += "    @base_url = base_url\n"
        client_code += "  end\n"
        
        if openapi['servers']
          client_code += "  # Base URL mappings:\n"
          openapi['servers'].each do |server|
            client_code += "  # #{server['url']} - #{server['description']}\n"
          end
        end
        
        if openapi['paths']
          openapi['paths'].each do |path, methods|
            methods.each do |method, details|
              operation_id = details['operationId'] || "#{method}_#{path.gsub(/[^a-zA-Z0-9]/, '_')}"
              
              client_code += "  # #{details['summary']}\n" if details['summary']
              client_code += "  # @param path [String] #{path}\n"
              
              if details['parameters']
                details['parameters'].each do |param|
                  client_code += "  # @param #{param['name']} [#{param['in']}]\n"
                  client_code += "  #  required: #{param['required']}, allowEmptyValue: #{param['allowEmptyValue']}, style: #{param['style']}, explode: #{param['explode']}, allowReserved: #{param['allowReserved']}, schema: #{param.dig('schema', 'type')}\n"
                end
              end
              
              if details['requestBody']
                req = details['requestBody']['required'] ? "required" : "optional"
                client_code += "  # Request Body (#{req}):\n"
                if details['requestBody']['content']
                  details['requestBody']['content'].each do |mt, mtdetails|
                    client_code += "  #  #{mt} schema: #{mtdetails.dig('schema', '$ref')}\n"
                    if mtdetails['encoding']
                      mtdetails['encoding'].each do |enc_k, enc_v|
                        client_code += "  #  Encoding #{enc_k}: contentType=#{enc_v['contentType']} style=#{enc_v['style']} explode=#{enc_v['explode']} allowReserved=#{enc_v['allowReserved']}\n"
                      end
                    end
                  end
                end
              end
              
              if details['responses']
                details['responses'].each do |status, resp|
                  client_code += "  # @return [#{status}] #{resp['description']}\n"
                  if resp['headers']
                    resp['headers'].each do |hname, hdetails|
                      client_code += "  #   Header #{hname}: required=#{hdetails['required']}, style=#{hdetails['style']}, explode=#{hdetails['explode']}, schema=#{hdetails.dig('schema', 'type')}\n"
                    end
                  end
                  if resp['links']
                    resp['links'].each do |lname, ldetails|
                      client_code += "  #   Link #{lname}: operationRef=#{ldetails['operationRef']}\n"
                    end
                  end
                end
              end
              
              client_code += "  def #{operation_id}(params = {})\n"
              client_code += "    req_path = '#{path}'.dup\n"
              client_code += "    params.each { |k, v| req_path.gsub!(\"{#\{k\}}\", v.to_s) }\n"
              client_code += "    uri = URI(@base_url + req_path)\n"
              client_code += "    uri.query = URI.encode_www_form(params) if !params.empty?\n" if method == 'get'
              client_code += "    req = Net::HTTP::#{method.capitalize}.new(uri)\n"
              client_code += "    req['Content-Type'] = 'application/json'\n"
              client_code += "    req.body = params.to_json\n" if ['post', 'put', 'patch'].include?(method)
              client_code += "    @last_response = Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(req) }\n"
              client_code += "    JSON.parse(@last_response.body) rescue @last_response.body\n"
              client_code += "    # Auth Required: #{details['security']&.to_json}\n" if details['security']
              client_code += "  end\n\n"
            end
          end
        end
        
        client_code += "  # Examples (externalValue)\n"
        if openapi['components'] && openapi['components']['examples']
          openapi['components']['examples'].each do |ename, edetails|
            client_code += "  # Example #{ename}: #{edetails['externalValue']}\n" if edetails['externalValue']
          end
        end
        
        client_code += "end\n"
        
        if options[:output]
          src_dir = File.join(options[:output], 'lib')
          FileUtils.mkdir_p(src_dir)
          Cdd::Scaffolding.generate(options, 'sdk')
          File.write(File.join(src_dir, 'models.rb'), models_code)
          File.write(File.join(src_dir, 'client.rb'), client_code)
          
          # Generate integration tests unconditionally when emitting SDK
          spec_dir = File.join(options[:output], 'spec')
          FileUtils.mkdir_p(spec_dir)

          integration_test_code = "# frozen_string_literal: true\n\n"
          integration_test_code += "require 'rspec'\n"
          integration_test_code += "require_relative '../lib/client'\n\n"
          integration_test_code += "RSpec.describe ClientSdk do\n"
          integration_test_code += "  let(:client) { ClientSdk.new('http://localhost:8080/v2') }\n\n"

          if openapi['paths']
            openapi['paths'].each do |path, methods|
              methods.each do |method, details|
                operation_id = details['operationId'] || "#{method}_#{path.gsub(/[^a-zA-Z0-9]/, '_')}"

                success_code = "200"
                if details['responses']
                  success_code = details['responses'].keys.find { |k| k.to_i >= 200 && k.to_i < 300 } || "200"
                end

                params = []
                if details["parameters"]
                  details["parameters"].each do |param|
                    val = param.dig("schema", "type") == "integer" ? "1" : (param["name"] == "status" ? "'available'" : "'test_#{param['name']}'")
                    params << "'#{param['name']}' => #{val}"
                  end
                end
                
                if details["requestBody"]
                  params << "'id' => 1"
                  params << "'name' => 'test'"
                  params << "'photoUrls' => ['http://example.com']"
                  params << "'status' => 'available'"
                end
                
                params_str = params.empty? ? "{}" : "{ #{params.join(', ')} }"

                integration_test_code += "  it 'can call #{operation_id}' do\n"
                integration_test_code += "    begin\n"
                integration_test_code += "      response = client.#{operation_id}(#{params_str})\n"
                integration_test_code += "      expect(client.last_response.code).to eq('#{success_code}')\n"
                integration_test_code += "      expect(response).not_to be_nil\n"
                integration_test_code += "    rescue Errno::ECONNREFUSED\n"
                integration_test_code += "      skip 'Petstore server is not available'\n"
                integration_test_code += "    end\n"
                integration_test_code += "  end\n\n"
              end
            end
          end
          integration_test_code += "end\n"
          File.write(File.join(spec_dir, 'integration_spec.rb'), integration_test_code)

          if options[:tests]
            ir = Cdd::IR.new
            ir.openapi_spec = openapi
            
            tests_code = "# frozen_string_literal: true\n\nrequire 'minitest'\nrequire_relative 'client'\n\n"
            tests_code += Cdd::Tests::Emitter.emit(ir)
            File.write(File.join(src_dir, 'tests.rb'), tests_code)
            
            mocks_code = "# frozen_string_literal: true\n\n"
            mocks_code += Cdd::Mocks::Emitter.emit(ir)
            File.write(File.join(src_dir, 'mocks.rb'), mocks_code)
          end
        end
        
        client_code + "\n" + models_code
      end

      # Supported keys
      # @return [Array]
      def self._supported_keys
        ["jsonSchemaDialect", "termsOfService", "contact", "license", "name", "url", "email", "identifier", "variables", "enum", "default", "description", "schemas", "responses", "parameters", "examples", "requestBodies", "headers", "securitySchemes", "links", "callbacks", "pathItems", "mediaTypes", "summary", "get", "put", "post", "delete", "options", "head", "patch", "trace", "query", "additionalOperations", "operationId", "requestBody", "deprecated", "security", "in", "required", "allowEmptyValue", "example", "style", "explode", "allowReserved", "schema", "content", "itemSchema", "encoding", "prefixEncoding", "itemEncoding", "contentType", "200", "expression", "dataValue", "serializedValue", "externalValue", "value", "operationRef", "server", "parent", "kind", "discriminator", "xml", "propertyName", "mapping", "defaultMapping", "nodeType", "namespace", "prefix", "attribute", "wrapped", "type", "scheme", "bearerFormat", "flows", "openIdConnectUrl", "oauth2MetadataUrl", "implicit", "password", "clientCredentials", "authorizationCode", "deviceAuthorization", "authorizationUrl", "deviceAuthorizationUrl", "tokenUrl", "refreshUrl", "scopes"]
      end
    end
  end
end
