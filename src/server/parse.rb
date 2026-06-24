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
        # Parse Sinatra routes to regenerate openapi paths securely
        tokens.each_with_index do |token, i|
          next unless token[1] == :on_ident && %w[get post put delete patch options head
                                                  trace query].include?(token[2].downcase)

          # Ensure this ident is at the start of a statement
          prev_meaningful = tokens[0...i].reverse.find { |t| t[1] != :on_sp && t[1] != :on_comment }
          next if prev_meaningful && prev_meaningful[1] == :on_symbeg
          next if prev_meaningful && prev_meaningful[1] == :on_period
          next if prev_meaningful && prev_meaningful[1] == :on_op && prev_meaningful[2] == '.'
          next if prev_meaningful && prev_meaningful[1] == :on_kw && prev_meaningful[2] == 'def'
          next if prev_meaningful && prev_meaningful[1] == :on_ident

          j = i + 1
          j += 1 while j < tokens.size && tokens[j][1] == :on_sp

          next if tokens[j].nil?
          next if tokens[j][1] == :on_lbracket
          next if tokens[j][1] == :on_op && tokens[j][2] == '='
          next if tokens[j][1] == :on_nl
          next if tokens[j][1] == :on_period

          if tokens[j][1] == :on_lparen
            j += 1
            j += 1 while j < tokens.size && tokens[j][1] == :on_sp
          end

          next unless tokens[j] && %i[on_tstring_beg on_tstring_content].include?(tokens[j][1])

          path_token = tokens[j..(j + 2)].find { |t| t[1] == :on_tstring_content }
          next unless path_token

          method = token[2].downcase
          path = path_token[2]

          next unless path.start_with?('/')
          next if path.start_with?('/mcp/')

          openapi_path = path.gsub(/:([a-zA-Z0-9_]+)/, '{\1}')

          ir.openapi_spec['paths'] ||= {}
          ir.openapi_spec['paths'][openapi_path] ||= {}
          ir.openapi_spec['paths'][openapi_path][method] ||= {
            'responses' => { '200' => { 'description' => 'OK' } }
          }

          path.scan(/:([a-zA-Z0-9_]+)/).flatten.each do |param_name|
            ir.openapi_spec['paths'][openapi_path][method]['parameters'] ||= []
            next if ir.openapi_spec['paths'][openapi_path][method]['parameters'].any? { |p| p['name'] == param_name && p['in'] == 'path' }

            ir.openapi_spec['paths'][openapi_path][method]['parameters'] << {
              'name' => param_name,
              'in' => 'path',
              'required' => true,
              'schema' => { 'type' => 'string' }
            }
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
