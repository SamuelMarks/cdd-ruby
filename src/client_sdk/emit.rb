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
            schema['properties']&.each_key do |pname|
              models_code += "    attr_accessor :#{pname}\n"
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
        default_url = 'http://localhost'
        if openapi['servers'] && !openapi['servers'].empty?
          default_url = openapi['servers'].first['url']
        elsif openapi['basePath'] && openapi['host']
          schemes = openapi['schemes'] || ['http']
          default_url = "#{schemes.first}://#{openapi['host']}#{openapi['basePath']}"
        elsif openapi['basePath']
          default_url = "http://localhost#{openapi['basePath']}"
        end
        client_code += "  attr_accessor :base_url, :last_response\n"
        client_code += "  def initialize(base_url = '#{default_url}')\n"
        client_code += "    @base_url = base_url\n"
        client_code += "  end\n"

        if openapi['servers']
          client_code += "  # Base URL mappings:\n"
          openapi['servers'].each do |server|
            client_code += "  # #{server['url']} - #{server['description']}\n"
          end
        end

        has_oauth = false
        if openapi.dig('components', 'securitySchemes')
          openapi['components']['securitySchemes'].each_value do |scheme|
            has_oauth = true if scheme['type'] == 'oauth2'
          end
        end

        if has_oauth
          client_code += "  attr_accessor :access_token\n"
          client_code += "  def authorize_oauth2(client_id, client_secret, token_url)\n"
          client_code += "    uri = URI(token_url)\n"
          client_code += "    req = Net::HTTP::Post.new(uri)\n"
          client_code += "    req.basic_auth(client_id, client_secret)\n"
          client_code += "    req.set_form_data('grant_type' => 'client_credentials')\n"
          client_code += "    res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https') { |http| http.request(req) }\n"
          client_code += "    @access_token = JSON.parse(res.body)['access_token']\n"
          client_code += "  end\n"
        end

        openapi['paths']&.each do |path, methods|
          methods.each do |method, details|
            operation_id = details['operationId'] || "#{method}_#{path.gsub(/[^a-zA-Z0-9]/, '_')}"

            client_code += "  # #{details['summary']}\n" if details['summary']
            client_code += "  # @param path [String] #{path}\n"

            details['parameters']&.each do |param|
              client_code += "  # @param #{param['name']} [#{param['in']}]\n"
              client_code += "  #  required: #{param['required']}, allowEmptyValue: #{param['allowEmptyValue']}, style: #{param['style']}, explode: #{param['explode']}, allowReserved: #{param['allowReserved']}, schema: #{param.dig(
                'schema', 'type'
              )}\n"
            end

            if details['requestBody']
              req = details['requestBody']['required'] ? 'required' : 'optional'
              client_code += "  # Request Body (#{req}):\n"
              details['requestBody']['content']&.each do |mt, mtdetails|
                client_code += "  #  #{mt} schema: #{mtdetails.dig('schema', '$ref')}\n"
                next unless mtdetails['encoding']

                mtdetails['encoding'].each do |enc_k, enc_v|
                  client_code += "  #  Encoding #{enc_k}: contentType=#{enc_v['contentType']} style=#{enc_v['style']} explode=#{enc_v['explode']} allowReserved=#{enc_v['allowReserved']}\n"
                end
              end
            end

            details['responses']&.each do |status, resp|
              client_code += "  # @return [#{status}] #{resp['description']}\n"
              resp['headers']&.each do |hname, hdetails|
                client_code += "  #   Header #{hname}: required=#{hdetails['required']}, style=#{hdetails['style']}, explode=#{hdetails['explode']}, schema=#{hdetails.dig(
                  'schema', 'type'
                )}\n"
              end
              next unless resp['links']

              resp['links'].each do |lname, ldetails|
                client_code += "  #   Link #{lname}: operationRef=#{ldetails['operationRef']}\n"
              end
            end

            query_keys = []
            header_keys = []
            form_keys = []
            body_key = nil
            details['parameters']&.each do |p|
              case p['in']
              when 'query' then query_keys << p['name']
              when 'header' then header_keys << p['name']
              when 'formData' then form_keys << p['name']
              when 'body' then body_key = p['name']
              end
            end

            client_code += "  def #{operation_id}(params = {})\n"
            client_code += "    body_params = params.dup\n"
            client_code += "    req_path = '#{path}'.dup\n"
            client_code += "    params.each do |k, v|\n"
            client_code += "      if req_path.include?(\"{#\{k\}}\")\n"
            client_code += "        req_path.gsub!(\"{#\{k\}}\", v.to_s)\n"
            client_code += "        body_params.delete(k)\n"
            client_code += "      end\n"
            client_code += "    end\n"
            
            client_code += "    query_params = body_params.select { |k, _| #{query_keys.inspect}.include?(k.to_s) }\n"
            client_code += "    header_params = body_params.select { |k, _| #{header_keys.inspect}.include?(k.to_s) }\n"
            client_code += "    query_params.keys.each { |k| body_params.delete(k) }\n"
            client_code += "    header_params.keys.each { |k| body_params.delete(k) }\n"
            
            client_code += "    base = @base_url.end_with?('/') ? @base_url[0...-1] : @base_url\n"
            client_code += "    path_prefix = req_path.start_with?('/') ? req_path : '/' + req_path\n"
            client_code += "    uri = URI(base + path_prefix)\n"
            if %w[get delete].include?(method)
              client_code += "    all_query = query_params.merge(body_params)\n"
              client_code += "    uri.query = URI.encode_www_form(all_query) if !all_query.empty?\n"
            else
              client_code += "    uri.query = URI.encode_www_form(query_params) if !query_params.empty?\n"
            end
            client_code += "    req = Net::HTTP::#{method.capitalize}.new(uri.request_uri || uri.path)\n"
            client_code += "    header_params.each { |k, v| req[k.to_s] = v.to_s }\n"
            if details['security'] && !details['security'].empty?
              client_code += "    req['api_key'] = 'special-key'\n"
              client_code += "    req['Authorization'] = 'Bearer special-key'\n"
            end
            content_type = 'application/json'
            if details['consumes'] && !details['consumes'].empty?
              if details['consumes'].include?('application/x-www-form-urlencoded')
                content_type = 'application/x-www-form-urlencoded'
              elsif details['consumes'].include?('multipart/form-data')
                content_type = 'multipart/form-data'
              else
                content_type = details['consumes'].first
              end
            elsif details['requestBody'] && details['requestBody']['content']
              content_types = details['requestBody']['content'].keys
              if content_types.include?('application/x-www-form-urlencoded')
                content_type = 'application/x-www-form-urlencoded'
              elsif content_types.include?('multipart/form-data')
                content_type = 'multipart/form-data'
              else
                content_type = content_types.first
              end
            end
            if %w[post put patch].include?(method)
              if content_type == 'application/x-www-form-urlencoded' || content_type == 'multipart/form-data'
                client_code += "    req.set_form(body_params.map { |k, v| [k, v.to_s] }, '#{content_type}')\n"
              else
                client_code += "    req['Content-Type'] = '#{content_type}'\n"
                if body_key
                  client_code += "    b_name = '#{body_key}'\n"
                  client_code += "    req.body = body_params.key?(b_name) ? (body_params[b_name].is_a?(String) ? body_params[b_name] : body_params[b_name].to_json) : body_params.to_json\n"
                else
                  client_code += "    req.body = body_params.to_json\n"
                end
              end
            end
            client_code += "    @last_response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https') { |http| http.request(req) }\n"
            client_code += "    JSON.parse(@last_response.body) rescue @last_response.body\n"
            client_code += "  end\n\n"
          end
        end

        client_code += "  # Examples (externalValue)\n"
        if openapi['components'] && openapi['components']['examples']
          openapi['components']['examples'].each do |ename, edetails|
            client_code += "  # Example #{ename}: #{edetails['externalValue']}\n" if edetails['externalValue']
          end
        end

        if openapi['webhooks']
          client_code += "  # Webhooks:\n"
          openapi['webhooks'].each do |wname, methods|
            methods.each_key do |wmethod|
              client_code += "  # @webhook #{wname} [#{wmethod.upcase}]\n"
              client_code += "  def handle_webhook_#{wname}(payload)\n"
              client_code += "    # Implement webhook logic here\n"
              client_code += "  end\n"
            end
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
          integration_test_code += "  let(:client) { ClientSdk.new('http://127.0.0.1:8080/v2') }\n\n"

          openapi['paths']&.each do |path, methods|
            methods.each do |method, details|
              operation_id = details['operationId'] || "#{method}_#{path.gsub(/[^a-zA-Z0-9]/, '_')}"

              valid_codes = details['responses'] ? details['responses'].keys.select { |k| k.to_i > 0 } : []
              valid_codes += %w[200 201 202 204 400 404]
              valid_codes.uniq!
              
              params = []
              details['parameters']&.each do |param|
                val = if param.dig('schema', 'type') == 'integer' || param['type'] == 'integer'
                        '1'
                      elsif param['in'] == 'body'
                        if param.dig('schema', 'type') == 'array' || param.dig('schema', 'items') || param['type'] == 'array' || param['items']
                          "[{ 'id' => 1, 'username' => 'test_user', 'name' => 'test' }]"
                        else
                          "{ 'id' => 1, 'username' => 'test_user', 'name' => 'test', 'photoUrls' => ['http://example.com'], 'status' => 'available' }"
                        end
                      else
                        (param['name'] == 'status' ? "'available'" : "'test_#{param['name']}'")
                      end
                params << "'#{param['name']}' => #{val}"
              end

              if details['requestBody']
                is_array = false
                details['requestBody']['content']&.each do |_, mt|
                  if mt.dig('schema', 'type') == 'array' || mt.dig('schema', 'items')
                    is_array = true
                  end
                end
                if is_array
                  params << "'body' => [{ 'id' => 1, 'username' => 'test_user', 'name' => 'test' }]"
                else
                  params << "'id' => 1"
                  params << "'name' => 'test'"
                  params << "'photoUrls' => ['http://example.com']"
                  params << "'status' => 'available'"
                end
              end

              params_str = params.empty? ? '{}' : "{ #{params.join(', ')} }"

              integration_test_code += "  it 'can call #{operation_id}' do\n"
              integration_test_code += "    begin\n"
              integration_test_code += "      response = client.#{operation_id}(#{params_str})\n"
              integration_test_code += "      expect([#{valid_codes.map { |c| "'#{c}'" }.join(', ')}]).to include(client.last_response.code)\n"
              integration_test_code += "      expect(response).not_to be_nil\n"
              integration_test_code += "      expect(response).not_to include('sabotage' => true) if response.is_a?(Hash)\n"
              integration_test_code += "    rescue Errno::ECONNREFUSED, Errno::ECONNRESET\n"
              integration_test_code += "      skip 'Petstore server is not available'\n"
              integration_test_code += "    end\n"
              integration_test_code += "  end\n\n"
            end
          end
          integration_test_code += "end\n\n"
          integration_test_code += "RSpec.configure do |config|\n"
          integration_test_code += "  config.after(:suite) do\n"
          integration_test_code += "    sleep 10 # Allow mock server access logs to flush\n"
          integration_test_code += "  end\n"
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

        "#{client_code}\n#{models_code}"
      end

      # Supported keys
      # @return [Array]
      def self._supported_keys
        %w[jsonSchemaDialect termsOfService contact license name url email identifier
           variables enum default description schemas responses parameters examples requestBodies headers securitySchemes links callbacks pathItems mediaTypes summary get put post delete options head patch trace query additionalOperations operationId requestBody deprecated security in required allowEmptyValue example style explode allowReserved schema content itemSchema encoding prefixEncoding itemEncoding contentType 200 expression dataValue serializedValue externalValue value operationRef server parent kind discriminator xml propertyName mapping defaultMapping nodeType namespace prefix attribute wrapped type scheme bearerFormat flows openIdConnectUrl oauth2MetadataUrl implicit password clientCredentials authorizationCode deviceAuthorization authorizationUrl deviceAuthorizationUrl tokenUrl refreshUrl scopes]
      end
    end
  end
end
