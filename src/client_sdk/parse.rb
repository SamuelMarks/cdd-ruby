# frozen_string_literal: true

module Cdd
  # Client SDK module
  module ClientSdk
    # SDK Parser
    class Parser
      # Parses SDK
      # @param tokens [Array] tokens
      # @param ir [Object] IR
      def self.parse(tokens, ir)
        current_class_name = nil
        current_def = false
        op_id = nil

        tokens.each_with_index do |token, i|
          if token[1] == :on_kw && token[2] == 'class'
            next_const = tokens[(i + 1)..(i + 5)].find { |t| t[1] == :on_const }
            current_class_name = next_const[2] if next_const
          elsif token[1] == :on_kw && token[2] == 'def'
            if current_class_name == 'ClientSdk'
              next_ident = tokens[(i + 1)..(i + 5)].find { |t| %i[on_ident on_kw].include?(t[1]) }
              if next_ident
                op_id = next_ident[2]
                current_def = true

                # Pre-populate defaults (fallback if not explicitly found in body)
                unless %w[initialize authorize_oauth2 mcp auth].include?(op_id) || op_id.start_with?('handle_webhook_')
                  ir.openapi_spec['paths'] ||= {}
                  ir.openapi_spec['paths']["/#{op_id}"] ||= { 'get' => { 'operationId' => op_id } }
                end
              end
            end
          elsif token[1] == :on_ident && token[2] == 'req_path' && current_def
            # Look for `req_path = '/foo/bar'.dup`
            if tokens[i + 2] && tokens[i + 2][2] == '='
              tstring = tokens[(i + 3)..(i + 10)].find { |t| t[1] == :on_tstring_content }
              if tstring && op_id
                http_method = 'get'
                tokens[i..(i + 50)].each do |t|
                  break if t[1] == :on_kw && t[2] == 'def'

                  if t[1] == :on_const && %w[Get Post Put Delete Patch Options Head Trace].include?(t[2])
                    http_method = t[2].downcase
                    break
                  end
                end

                path_str = tstring[2]

                ir.openapi_spec['paths'] ||= {}
                # Remove the fallback path
                ir.openapi_spec['paths'].delete("/#{op_id}")

                ir.openapi_spec['paths'][path_str] ||= {}
                ir.openapi_spec['paths'][path_str][http_method] = { 'operationId' => op_id }

                current_def = false
                op_id = nil
              end
            end
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
