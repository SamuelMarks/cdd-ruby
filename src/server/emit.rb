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
            next unless server['variables']

            server['variables'].each do |k, v|
              ruby_code += "#   Variable #{k}: default=#{v['default']} enum=#{v['enum']&.join(',')}\n"
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
            schema['properties']&.each do |prop_name, prop_details|
              ruby_code += "  # property: #{prop_name} (#{prop_details['type']})\n"
            end
            if schema['discriminator']
              ruby_code += "  # Discriminator: #{schema['discriminator']['propertyName']}\n"
              if schema['discriminator']['mapping']
                ruby_code += "  # Mapping: #{schema['discriminator']['mapping'].to_json}\n"
              end
            end
            ruby_code += "  # XML Mapping: #{schema['xml'].to_json}\n" if schema['xml']
            ruby_code += "end\n\n"
          end
        end

        openapi['paths']&.each do |path, methods|
          sinatra_path = path.gsub(/\{([^}]+)\}/, ':\1')
          methods.each do |method, details|
            ruby_code += "# Operation: #{details['operationId'] || method.upcase}\n"
            ruby_code += "# Summary: #{details['summary']}\n" if details['summary']
            ruby_code += "# Description: #{details['description']}\n" if details['description']
            ruby_code += "# Deprecated: true\n" if details['deprecated']
            details['parameters']&.each do |param|
              req = param['required'] ? 'required' : 'optional'
              ruby_code += "# Param [#{param['in']}]: #{param['name']} (#{req})\n"
            end
            if details['requestBody']
              ruby_code += "# Request Body: expected\n"
              details['requestBody']['content']&.each_key do |mt|
                ruby_code += "# Content-Type: #{mt}\n"
              end
            end
            ruby_code += "#{method.downcase} '#{sinatra_path}' do\n"
            ruby_code += "  content_type :json\n"
            ruby_code += "  { message: 'Not implemented' }.to_json\n"
            ruby_code += "end\n\n"
          end
        end

        tools_array = []
        openapi['paths']&.each do |path, methods|
          methods.each do |method, details|
            operation_id = details['operationId'] || "#{method}_#{path.gsub(/[^a-zA-Z0-9]/, '_')}"
            tool = {
              name: operation_id,
              description: details['summary'] || "Call #{method.upcase} #{path}",
              inputSchema: { type: 'object', properties: {}, required: [] }
            }
            details['parameters']&.each do |param|
              tool[:inputSchema][:properties][param['name']] = { type: 'string', description: param['in'] }
              tool[:inputSchema][:required] << param['name'] if param['required']
            end
            tools_array << tool
          end
        end

        ruby_code += "set :server, :thin\n"
        ruby_code += "set :mcp_connections, []\n"
        ruby_code += "get '/mcp/sse' do\n"
        ruby_code += "  content_type 'text/event-stream'\n"
        ruby_code += "  stream(:keep_open) do |out|\n"
        ruby_code += "    settings.mcp_connections << out\n"
        ruby_code += "    out << \"event: endpoint\\ndata: /mcp/message\\n\\n\"\n"
        ruby_code += "    out.callback { settings.mcp_connections.delete(out) }\n"
        ruby_code += "  end\n"
        ruby_code += "end\n\n"

        ruby_code += "post '/mcp/message' do\n"
        ruby_code += "  begin\n"
        ruby_code += "    req = JSON.parse(request.body.read)\n"
        ruby_code += "  rescue JSON::ParserError\n"
        ruby_code += "    status 202\n"
        ruby_code += "    resp = { jsonrpc: '2.0', error: { code: -32700, message: 'Parse error' } }\n"
        ruby_code += "    settings.mcp_connections.each { |out| out << \"event: message\\ndata: \#{resp.to_json}\\n\\n\" }\n"
        ruby_code += "    return\n"
        ruby_code += "  end\n"
        ruby_code += "  if req['id'].nil?\n"
        ruby_code += "    if req['method'] == 'notifications/cancelled'\n"
        ruby_code += "      # Cancelled request\n"
        ruby_code += "    end\n"
        ruby_code += "    return\n"
        ruby_code += "  end\n"
        ruby_code += "  resp = { jsonrpc: '2.0', id: req['id'], result: { _meta: {} } }\n"
        ruby_code += "  if req['method'] == 'initialize'\n"
        ruby_code += "    resp[:result] = { capabilities: { tools: { listChanged: true }, logging: {}, experimental: {}, roots: { listChanged: true }, sampling: {} }, serverInfo: { name: 'mcp-server', version: '1.0.0' }, protocolVersion: '2024-11-05', instructions: '' }\n"
        ruby_code += "  elsif req['method'] == 'ping'\n"
        ruby_code += "    resp[:result] = {}\n"
        ruby_code += "  elsif req['method'] == 'logging/setLevel'\n"
        ruby_code += "    resp[:result] = {}\n"
        ruby_code += "  elsif req['method'] == 'roots/list'\n"
        ruby_code += "    resp[:result] = { roots: [] }\n"
        ruby_code += "  elsif req['method'] == 'resources/templates/list'\n"
        ruby_code += "    resp[:result] = { resourceTemplates: [] }\n"
        ruby_code += "  elsif req['method'] == 'sampling/createMessage'\n"
        ruby_code += "    resp[:result] = { role: 'assistant', model: 'stub-model', content: { type: 'text', text: 'sampled' } }\n"
        ruby_code += "  elsif req['method'] == 'completion/complete'\n"
        ruby_code += "    resp[:result] = { completion: { values: [], total: 0, hasMore: false } }\n"
        ruby_code += "  elsif req['method'] == 'tools/list'\n"
        ruby_code += "    resp[:result] = { tools: #{tools_array.to_json} }\n"
        ruby_code += "  elsif req['method'] == 'tools/call'\n"
        ruby_code += "    resp[:result] = { content: [{ type: 'text', text: 'Calling tool ' + req.dig('params', 'name').to_s }] }\n"
        ruby_code += "  else\n"
        ruby_code += "    resp = { jsonrpc: '2.0', id: req['id'], error: { code: -32601, message: 'Method not found' } }\n"
        ruby_code += "  end\n"
        ruby_code += "  settings.mcp_connections.each { |out| out << \"event: message\\ndata: \#{resp.to_json}\\n\\n\" }\n"
        ruby_code += "  status 202\n"
        ruby_code += "end\n\n"

        FileUtils.mkdir_p(options[:output]) if options[:output]
        if options[:output]
          Cdd::Scaffolding.generate(options, 'server')
          File.write(File.join(options[:output], 'server.rb'), ruby_code)

          if options[:tests]
            ir = Cdd::IR.new
            ir.openapi_spec = openapi

            tests_code = "# frozen_string_literal: true\n\nrequire 'minitest'\nrequire_relative 'server'\n\n"
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
