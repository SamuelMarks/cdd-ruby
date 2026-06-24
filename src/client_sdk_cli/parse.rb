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
        in_cli_case_statement = false
        case_nesting = 0
        current_when = false
        op_id = nil

        tokens.each_with_index do |token, i|
          if token[1] == :on_kw && token[2] == 'case'
            case_nesting += 1
            next_ident = tokens[(i + 1)..(i + 5)].find { |t| t[1] == :on_ident }
            in_cli_case_statement = true if next_ident && next_ident[2] == 'command'
          elsif token[1] == :on_kw && token[2] == 'end'
            if case_nesting.positive?
              in_cli_case_statement = false if in_cli_case_statement && case_nesting == 1
              case_nesting -= 1
            end
          elsif token[1] == :on_kw && token[2] == 'when'
            current_when = true if in_cli_case_statement
          elsif token[1] == :on_tstring_content && current_when
            op_id = token[2]

            if op_id != 'mcp'
              http_method = 'get'
              path_str = "/#{op_id}"

              # Lookahead for `puts 'Calling METHOD /path'`
              tokens[i..(i + 20)].each_with_index do |t, _j|
                break if t[1] == :on_kw && t[2] == 'when'

                next unless t[1] == :on_tstring_content && t[2].start_with?('Calling ')

                # e.g., "Calling GET /users"
                parts = t[2].split
                if parts.length >= 3
                  http_method = parts[1].downcase
                  path_str = parts[2]
                end
                break
              end

              ir.openapi_spec['paths'] ||= {}
              ir.openapi_spec['paths'][path_str] ||= {}
              ir.openapi_spec['paths'][path_str][http_method] = { 'operationId' => op_id }
            end
            current_when = false
            op_id = nil
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
