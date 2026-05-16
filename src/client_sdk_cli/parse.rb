# frozen_string_literal: true

module Cdd
  # Client SDK CLI module
  module ClientSdkCli
    # CLI Parser
    class Parser
      # Parses CLI
      # @param tokens [Array] tokens
      # @param ir [Object] IR
      def self.parse(tokens, ir)
        current_when = nil
        tokens.each_with_index do |token, _i|
          if token[1] == :on_kw && token[2] == 'when'
            current_when = true
          elsif token[1] == :on_tstring_content && current_when
            op_id = token[2]
            ir.openapi_spec['paths'] ||= {}
            ir.openapi_spec['paths']["/#{op_id}"] ||= {
              'get' => { 'operationId' => op_id }
            }
            current_when = nil
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
