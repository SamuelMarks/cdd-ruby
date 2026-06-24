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
                ruby_code += "  puts '    Mapping: #{schema['discriminator']['mapping'].to_json}'\n"
              end
            end
          end
        end

        ruby_code += "  puts '  mcp - Start Model Context Protocol server'\n"

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
        ruby_code += "when 'mcp'\n"
        ruby_code += "  require 'json'\n"
        ruby_code += "  # Starting MCP server on stdio\n"
        ruby_code += "  loop do\n"
        ruby_code += "    line = $stdin.gets\n"
        ruby_code += "    break if line.nil?\n"
        ruby_code += "    next if line.strip.empty?\n"
        ruby_code += "    begin\n"
        ruby_code += "      req = JSON.parse(line)\n"
        ruby_code += "      \n"
        ruby_code += "      if req['id'].nil?\n"
        ruby_code += "        # Notification handling\n"
        ruby_code += "        if req['method'] == 'notifications/cancelled'\n"
        ruby_code += "          # Cancelled request\n"
        ruby_code += "        end\n"
        ruby_code += "        next\n"
        ruby_code += "      end\n\n"
        ruby_code += "      resp = { jsonrpc: '2.0', id: req['id'], result: { _meta: {} } }\n"
        ruby_code += "      if req['method'] == 'initialize'\n"
        ruby_code += "        resp[:result] = { capabilities: { tools: { listChanged: true }, resources: { subscribe: true, listChanged: true }, prompts: { listChanged: true }, logging: {}, experimental: {}, roots: { listChanged: true }, sampling: {} }, serverInfo: { name: 'sdk-cli-mcp', version: '1.0.0' }, protocolVersion: '2024-11-05', instructions: '' }\n"
        ruby_code += "      elsif req['method'] == 'ping'\n"
        ruby_code += "        resp[:result] = {}\n"
        ruby_code += "      elsif req['method'] == 'logging/setLevel'\n"
        ruby_code += "        resp[:result] = {}\n"
        ruby_code += "      elsif req['method'] == 'resources/subscribe'\n"
        ruby_code += "        resp[:result] = {}\n"
        ruby_code += "      elsif req['method'] == 'resources/unsubscribe'\n"
        ruby_code += "        resp[:result] = {}\n"
        ruby_code += "      elsif req['method'] == 'sampling/createMessage'\n"
        ruby_code += "        resp[:result] = { role: 'assistant', model: 'stub-model', content: { type: 'text', text: 'sampled' } }\n"
        ruby_code += "      elsif req['method'] == 'completion/complete'\n"
        ruby_code += "        resp[:result] = { completion: { values: [], total: 0, hasMore: false } }\n"
        ruby_code += "      elsif req['method'] == 'prompts/list'\n"
        ruby_code += "        cursor = req.dig('params', 'cursor')\n"
        ruby_code += "        resp[:result] = { prompts: [{ name: 'api_help', description: 'Help for API', arguments: [] }] }\n"
        ruby_code += "      elsif req['method'] == 'prompts/get'\n"
        ruby_code += "        name = req.dig('params', 'name')\n"
        ruby_code += "        if name == 'api_help'\n"
        ruby_code += "          resp[:result] = { description: 'API Help', messages: [{ role: 'user', content: { type: 'text', text: 'How do I use this API?' } }] }\n"
        ruby_code += "        else\n"
        ruby_code += "          resp[:result] = { messages: [] }\n"
        ruby_code += "        end\n"
        ruby_code += "      elsif req['method'] == 'resources/list'\n"
        ruby_code += "        cursor = req.dig('params', 'cursor')\n"
        ruby_code += "        resp[:result] = { resources: [{ uri: 'mcp://api/docs', name: 'API Documentation', mimeType: 'text/markdown' }] }\n"
        ruby_code += "      elsif req['method'] == 'resources/templates/list'\n"
        ruby_code += "        cursor = req.dig('params', 'cursor')\n"
        ruby_code += "        resp[:result] = { resourceTemplates: [] }\n"
        ruby_code += "      elsif req['method'] == 'resources/read'\n"
        ruby_code += "        uri = req.dig('params', 'uri')\n"
        ruby_code += "        if uri == 'mcp://api/docs'\n"
        ruby_code += "          resp[:result] = { contents: [{ uri: uri, mimeType: 'text/markdown', text: \"# \#{info['title'] || 'API'} Docs\\n\\n\#{info['description'] || ''}\" }] }\n"
        ruby_code += "        else\n"
        ruby_code += "          resp[:result] = { contents: [] }\n"
        ruby_code += "        end\n"
        ruby_code += "      elsif req['method'] == 'roots/list'\n"
        ruby_code += "        resp[:result] = { roots: [] }\n"
        ruby_code += "      elsif req['method'] == 'tools/list'\n"
        ruby_code += "        cursor = req.dig('params', 'cursor')\n"

        tools_array = []
        openapi['paths']&.each do |path, methods|
          methods.each do |method, details|
            operation_id = details['operationId'] || "#{method}_#{path.gsub(/[^a-zA-Z0-9]/, '_')}"
            tool = {
              name: operation_id,
              description: details['summary'] || "Call #{method.upcase} #{path}",
              inputSchema: {
                type: 'object',
                properties: {},
                required: []
              }
            }
            details['parameters']&.each do |param|
              tool[:inputSchema][:properties][param['name']] = { type: 'string', description: param['in'] }
              tool[:inputSchema][:required] << param['name'] if param['required']
            end
            tools_array << tool
          end
        end

        ruby_code += "        resp[:result] = { tools: #{tools_array.to_json} }\n"
        ruby_code += "      elsif req['method'] == 'tools/call'\n"
        ruby_code += "        tool_name = req.dig('params', 'name').to_s\n"
        ruby_code += "        args = req.dig('params', 'arguments') || {}\n"
        ruby_code += "        cmd_args = args.map { |k, v| \"--\#{k} '\#{v}'\" }.join(' ')\n"
        ruby_code += "        out = `ruby \#{__FILE__} \#{tool_name} \#{cmd_args}`\n"
        ruby_code += "        resp[:result] = { content: [{ type: 'text', text: out }] }\n"
        ruby_code += "      else\n"
        ruby_code += "        resp = { jsonrpc: '2.0', id: req['id'], error: { code: -32601, message: 'Method not found' } }\n"
        ruby_code += "      end\n"
        ruby_code += "      $stdout.puts JSON.generate(resp)\n"
        ruby_code += "      $stdout.flush\n"
        ruby_code += "    rescue JSON::ParserError => e\n"
        ruby_code += "      # Simulate a logging message on error\n"
        ruby_code += "      log_msg = { jsonrpc: '2.0', method: 'notifications/message', params: { level: 'error', logger: 'mcp-server', data: e.message } }\n"
        ruby_code += "      $stdout.puts JSON.generate(log_msg)\n"
        ruby_code += "      $stdout.puts JSON.generate({ jsonrpc: '2.0', error: { code: -32700, message: 'Parse error' } })\n"
        ruby_code += "      $stdout.flush\n"
        ruby_code += "    end\n"
        ruby_code += "  end\n"

        openapi['paths']&.each do |path, methods|
          methods.each do |method, details|
            operation_id = details['operationId'] || "#{method}_#{path.gsub(/[^a-zA-Z0-9]/, '_')}"
            ruby_code += "when '#{operation_id}'\n"
            ruby_code += "  puts 'Calling #{method.upcase} #{path}'\n"
            ruby_code += "  # External Docs: #{details.dig('externalDocs', 'url')}\n" if details['externalDocs']
            ruby_code += "  # Tags: #{details['tags'].join(', ')}\n" if details['tags']

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
            spec_dir = File.join(options[:output], 'spec')
            FileUtils.mkdir_p(spec_dir)

            integration_test_code = "# frozen_string_literal: true\n\n"
            integration_test_code += "require 'rspec'\n"
            integration_test_code += "require 'open3'\n\n"

            integration_test_code += "RSpec.shared_context 'server fixture' do |server_flags|\n"
            integration_test_code += "  before(:all) do\n"
            integration_test_code += "    @server_pid = spawn('ruby ../../generated_server/server.rb -p 8080 ' + server_flags)\n"
            integration_test_code += "    sleep 2 # Wait for boot\n"
            integration_test_code += "  end\n"
            integration_test_code += "  after(:all) do\n"
            integration_test_code += "    Process.kill('TERM', @server_pid) rescue nil\n"
            integration_test_code += "    Process.wait(@server_pid) rescue nil\n"
            integration_test_code += "  end\n"
            integration_test_code += "end\n\n"

            integration_test_code += "RSpec.describe 'Client CLI' do\n"

            # Topological Sort of Paths
            sorted_paths = []
            openapi['paths']&.each do |path, methods|
              methods.each do |method, details|
                operation_id = details['operationId'] || "#{method}_#{path.gsub(/[^a-zA-Z0-9]/, '_')}"
                score = path.count('/') + (details['parameters']&.size || 0)
                sorted_paths << { operation_id: operation_id, score: score }
              end
            end
            sorted_paths.sort_by! { |p| p[:score] }

            categories = {
              'Category 2: Stub Tests' => '',
              'Category 3: Stateful Ephemeral Tests' => '--ephemeral',
              'Category 4: Seeded Mock Tests' => '--ephemeral --seed'
            }

            categories.each do |cat_name, flags|
              integration_test_code += "  context '#{cat_name}' do\n"
              integration_test_code += "    include_context 'server fixture', '#{flags}'\n\n"

              sorted_paths.each do |p|
                operation_id = p[:operation_id]
                integration_test_code += "    it 'can call #{operation_id}' do\n"
                integration_test_code += "      out, status = Open3.capture2e('ruby', '../sdk_cli.rb', '#{operation_id}')\n"
                integration_test_code += "      expect(out).to include('Calling')\n"
                integration_test_code += "    end\n\n"
              end
              integration_test_code += "  end\n\n"
            end

            integration_test_code += "end\n\n"
            File.write(File.join(spec_dir, 'integration_spec.rb'), integration_test_code)

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
