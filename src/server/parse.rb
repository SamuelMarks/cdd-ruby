# frozen_string_literal: true

module Cdd
  # Server generation module
  module ServerGen
    # Server Parser
    class Parser
      # Parses Server
      # @param tokens [Array] tokens
      # @param ir [Object] IR
      def self.parse(tokens, ir)
        # Parse Sinatra routes to regenerate openapi paths
        current_method = nil
        current_path = nil

        tokens.each_with_index do |token, i|
          if token[1] == :on_ident && %w[get post put delete patch options head trace query].include?(token[2])
            # Check if next tokens are space and string
            next_token = tokens[i + 1]
            tokens[i + 2] || tokens[i + 3] # simplified
            current_method = token[2] if next_token && next_token[1] == :on_sp
          elsif token[1] == :on_tstring_content && current_method
            current_path = token[2]
            openapi_path = current_path.gsub(/:([a-zA-Z0-9_]+)/, '{\1}')
            ir.openapi_spec['paths'] ||= {}
            ir.openapi_spec['paths'][openapi_path] ||= {}
            ir.openapi_spec['paths'][openapi_path][current_method] ||= {
              'responses' => { '200' => { 'description' => 'OK' } }
            }
            # Also extract param definitions from path
            openapi_path.scan(/\{(\w+)\}/).flatten.each do |param_name|
              ir.openapi_spec['paths'][openapi_path][current_method]['parameters'] ||= []
              next if ir.openapi_spec['paths'][openapi_path][current_method]['parameters'].any? do |p|
                p['name'] == param_name && p['in'] == 'path'
              end

              ir.openapi_spec['paths'][openapi_path][current_method]['parameters'] << {
                'name' => param_name,
                'in' => 'path',
                'required' => true,
                'schema' => { 'type' => 'string' }
              }
            end
            current_method = nil
          end
        end
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
