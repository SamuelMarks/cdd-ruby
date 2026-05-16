# frozen_string_literal: true

require 'json'
require 'fileutils'

module Cdd
  # Client SDK CLI module
  module ClientSdkCli
    # CLI Emitter
    class Emitter
      # Emits SDK CLI
      # @param options [Hash] options
      def self.emit_sdk_cli(options)
        input_file = options[:input] || Dir.glob("#{options[:input_dir]}/*.json").first
        openapi = JSON.parse(File.read(input_file))

        ruby_code = "# frozen_string_literal: true\n\n"

        info = openapi['info'] || {}
        ruby_code += "# Auto-generated SDK CLI for #{info['title'] || 'API'}\n"
        ruby_code += "# Version: #{info['version']}\n" if info['version']
        ruby_code += "# Summary: #{info['summary']}\n" if info['summary']
        ruby_code += "# Contact Name: #{info.dig('contact', 'name')}\n" if info.dig('contact', 'name')
        ruby_code += "# License URL: #{info.dig('license', 'url')}\n" if info.dig('license', 'url')

        ruby_code += "require 'json'\nrequire 'net/http'\n\n"
        ruby_code += "def print_help\n"
        ruby_code += "  puts 'Usage: sdk_cli [command] [options]'\n"

        if openapi['servers']
          ruby_code += "  puts 'Servers:'\n"
          openapi['servers'].each do |server|
            ruby_code += "  puts '  #{server['url']} - #{server['description']}'\n"
            next unless server['variables']

            server['variables'].each do |k, v|
              ruby_code += "  puts '    var #{k} default=#{v['default']} enum=#{v['enum']&.join(',')}'\n"
            end
          end
        end

        if openapi['components']
          if openapi['components']['securitySchemes']
            ruby_code += "  puts 'Security Required:'\n"
            openapi['components']['securitySchemes'].each do |name, scheme|
              ruby_code += "  puts '  #{name} (#{scheme['type']})'\n"
              if scheme['type'] == 'oauth2'
                ruby_code += "  puts '  OAuth Scopes: #{scheme.dig('flows', 'implicit',
                                                                   'scopes')&.keys&.join(',')}'\n"
              end
            end
          end
          if openapi['components']['schemas']
            ruby_code += "  puts 'Schemas Available:'\n"
            openapi['components']['schemas'].each do |name, schema|
              ruby_code += "  puts '  #{name}'\n"
              next unless schema['discriminator']

              ruby_code += "  puts '    Discriminator: #{schema['discriminator']['propertyName']}'\n"
              if schema['discriminator']['mapping']
                ruby_code += "  puts '    Mapping: #{schema['discriminator']['mapping']&.to_json}'\n"
              end
            end
          end
        end

        openapi['paths']&.each do |path, methods|
          methods.each do |method, details|
            operation_id = details['operationId'] || "#{method}_#{path.gsub(/[^a-zA-Z0-9]/, '_')}"
            summary = details['summary'] ? " - #{details['summary']}" : ''
            ruby_code += "  puts '  #{operation_id}#{summary}'\n"
            next unless details['parameters']

            details['parameters'].each do |param|
              req = param['required'] ? '*' : ''
              ruby_code += "  puts '    --#{param['name']} [#{param['in']}] #{req}'\n"
            end
          end
        end
        ruby_code += "end\n\n"

        ruby_code += "if ARGV.empty? || ARGV.include?('-h') || ARGV.include?('--help')\n"
        ruby_code += "  print_help\n  exit\nend\n\n"

        ruby_code += "command = ARGV.shift\ncase command\n"

        openapi['paths']&.each do |path, methods|
          methods.each do |method, details|
            operation_id = details['operationId'] || "#{method}_#{path.gsub(/[^a-zA-Z0-9]/, '_')}"
            ruby_code += "when '#{operation_id}'\n"
            ruby_code += "  puts 'Calling #{method.upcase} #{path}'\n"
            ruby_code += "  # External Docs: #{details.dig('externalDocs', 'url')}\n" if details['externalDocs']
            ruby_code += "  # Tags: #{details['tags']&.join(', ')}\n" if details['tags']

            if details['requestBody']
              ruby_code += "  # Body required: #{details['requestBody']['required']}\n"
              details['requestBody']['content']&.each do |mt, mtdetails|
                ruby_code += "  # Accepts #{mt}\n"
                ruby_code += "  # Example: #{mtdetails['examples'].keys.first}\n" if mtdetails['examples']
                ruby_code += "  # Encoding: #{mtdetails['encoding'].keys.join(',')}\n" if mtdetails['encoding']
              end
            end
            details['responses']&.each do |status, resp|
              ruby_code += "  # Expects #{status}: #{resp['description']}\n"
              ruby_code += "  # Returns headers: #{resp['headers'].keys.join(',')}\n" if resp['headers']
              resp['content']&.each_key do |mt|
                ruby_code += "  # Returns #{mt}\n"
              end
              ruby_code += "  # Links: #{resp['links'].keys.join(',')}\n" if resp['links']
            end
            ruby_code += "  # Callbacks: #{details['callbacks'].keys.join(',')}\n" if details['callbacks']
          end
        end

        ruby_code += "else\n  puts \"Unknown command: \#{command}\"\nend\n"

        FileUtils.mkdir_p(options[:output]) if options[:output]
        if options[:output]
          Cdd::Scaffolding.generate(options, 'sdk_cli')
          File.write(File.join(options[:output], 'sdk_cli.rb'), ruby_code)

          if options[:tests]
            ir = Cdd::IR.new
            ir.openapi_spec = openapi

            tests_code = "# frozen_string_literal: true\n\nrequire 'minitest'\nrequire_relative 'sdk_cli'\n\n"
            tests_code += Cdd::Tests::Emitter.emit(ir)
            File.write(File.join(options[:output], 'tests.rb'), tests_code)

            mocks_code = "# frozen_string_literal: true\n\n"
            mocks_code += Cdd::Mocks::Emitter.emit(ir)
            File.write(File.join(options[:output], 'mocks.rb'), mocks_code)
          end
        end

        ruby_code
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
