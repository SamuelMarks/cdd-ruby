# frozen_string_literal: true

require 'json'
require 'fileutils'
require_relative '../arazzo/emit'

# Core namespace for the CDD Ruby compiler and OpenAPI toolchain.
module Cdd
  # Client SDK CLI generation and parsing module.
  module ClientSdkCli
    # Emitter for generating a standalone Ruby CLI script, workflow runner, and MCP server.
    class Emitter
      # Emits a standalone CLI script and optional test/mock scaffolding from an OpenAPI or Arazzo definition.
      #
      # @param options [Hash] generation options (`:input`, `:input_dir`, `:output`, `:tests`, `:arazzo`)
      # @return [String] generated CLI Ruby source code
      def self.emit_sdk_cli(options)
        input_file = options[:input] || Dir.glob("#{options[:input_dir]}/*.json").first
        raw_spec = JSON.parse(File.read(input_file))
        openapi, arazzo = Cdd::ClientSdk::Emitter.split_openapi_and_arazzo(raw_spec, options[:arazzo])

        ruby_code = emit_header_and_help(openapi, arazzo)
        ruby_code += emit_mcp_loop(openapi, arazzo)
        ruby_code += emit_command_branches(openapi, arazzo)
        write_cli_artifacts(options, openapi, ruby_code) if options[:output]
        ruby_code
      end

      # Builds the MCP tools list array from an OpenAPI specification's `paths` and optional Arazzo `workflows`.
      #
      # @param openapi [Hash] parsed OpenAPI specification
      # @param arazzo [Hash, nil] optional parsed Arazzo specification
      # @return [Array<Hash>] MCP tool definitions
      def self.build_mcp_tools(openapi, arazzo = nil)
        ir = Cdd::IR.new(openapi)
        tools_array = []
        ir.typed_paths.each do |path_item|
          path_item.operations.each do |method, op|
            operation_id = Cdd::TokenScanner.operation_id_for(method, path_item.path,
                                                              { 'operationId' => op.operation_id }, collapse: false)
            tool = {
              name: operation_id,
              description: op.summary || "Call #{method.upcase} #{path_item.path}",
              inputSchema: { type: 'object', properties: {}, required: [] }
            }
            op.parameters.each do |param|
              tool[:inputSchema][:properties][param.name] = { type: 'string', description: param.in_location }
              tool[:inputSchema][:required] << param.name if param.required
            end
            tools_array << tool
          end
        end
        append_arazzo_mcp_tools(tools_array, arazzo) if arazzo.is_a?(Hash)
        tools_array
      end

      # Appends Arazzo workflow tool definitions to `tools_array`.
      #
      # @param tools_array [Array<Hash>] mutable MCP tools list
      # @param arazzo [Hash] parsed Arazzo specification
      # @return [void]
      def self.append_arazzo_mcp_tools(tools_array, arazzo)
        ir = Cdd::IR.new(nil, arazzo)
        ir.typed_arazzo.workflows.each do |workflow|
          wf_id = workflow.workflow_id
          tools_array << {
            name: wf_id,
            description: workflow.summary || workflow.description || "Run workflow #{wf_id}",
            inputSchema: workflow.inputs || { type: 'object', properties: {}, required: [] }
          }
        end
      end

      # Emits the file header, imports, and `print_help` function.
      #
      # @param openapi [Hash] parsed OpenAPI specification
      # @param arazzo [Hash, nil] optional parsed Arazzo specification
      # @return [String] Ruby code for header and help printer
      def self.emit_header_and_help(openapi, arazzo = nil)
        info = openapi['info'] || {}
        out = "# frozen_string_literal: true\n\n"
        out += Cdd::Arazzo::Emitter.emit(Cdd::IR.from_arazzo_hash(arazzo)) if arazzo.is_a?(Hash)
        out += "# Auto-generated SDK CLI for #{info['title'] || 'API'}\n"
        out += "# Version: #{info['version']}\n" if info['version']
        out += "# Summary: #{info['summary']}\n" if info['summary']
        out += "# Contact Name: #{info.dig('contact', 'name')}\n" if info.dig('contact', 'name')
        out += "# License URL: #{info.dig('license', 'url')}\n" if info.dig('license', 'url')
        out += "require 'json'\nrequire 'net/http'\nrequire 'open3'\n\n"
        out += "def print_help\n  puts 'Usage: sdk_cli [command] [options]'\n"
        out += emit_help_servers(openapi['servers'])
        out += emit_help_components(openapi['components'])
        out += "  puts '  mcp - Start Model Context Protocol server'\n"
        out += emit_help_workflows(arazzo['workflows']) if arazzo.is_a?(Hash)
        out += emit_help_paths(openapi['paths'])
        "#{out}end\n\nif ARGV.empty? || ARGV.include?('-h') || ARGV.include?('--help')\n  print_help\n  exit\nend\n\n"
      end

      # Emits workflow help lines for `print_help`.
      #
      # @param workflows [Array<Hash>, nil] Arazzo workflows list
      # @return [String] Ruby puts statements
      def self.emit_help_workflows(workflows)
        return '' unless workflows.is_a?(Array) && !workflows.empty?

        out = "  puts 'Workflows:'\n  puts '  workflow list | run <workflowId>'\n"
        workflows.each do |workflow|
          summary = workflow['summary'] ? " - #{workflow['summary']}" : ''
          line_lit = Cdd::TokenScanner.single_quote_literal("    #{workflow['workflowId']}#{summary}")
          out += "  puts #{line_lit}\n"
        end
        out
      end

      # Emits server help lines for `print_help`.
      #
      # @param servers [Array<Hash>, nil] OpenAPI servers list
      # @return [String] Ruby puts statements
      def self.emit_help_servers(servers)
        return '' unless servers

        out = "  puts 'Servers:'\n"
        servers.each do |server|
          srv_lit = Cdd::TokenScanner.single_quote_literal("  #{server['url']} - #{server['description']}")
          out += "  puts #{srv_lit}\n"
          server['variables']&.each do |k, v|
            var_lit = Cdd::TokenScanner.single_quote_literal(
              "    var #{k} default=#{v['default']} enum=#{v['enum']&.join(',')}"
            )
            out += "  puts #{var_lit}\n"
          end
        end
        out
      end

      # Emits security scheme and schema help lines for `print_help`.
      #
      # @param components [Hash, nil] OpenAPI components hash
      # @return [String] Ruby puts statements
      def self.emit_help_components(components)
        return '' unless components

        emit_help_security_schemes(components['securitySchemes']) + emit_help_schemas(components['schemas'])
      end

      # Emits security scheme help lines for `print_help`.
      #
      # @param security_schemes [Hash, nil] securitySchemes component map
      # @return [String] Ruby puts statements
      def self.emit_help_security_schemes(security_schemes)
        return '' unless security_schemes

        out = "  puts 'Security Required:'\n"
        security_schemes.each do |name, scheme|
          out += "  puts #{Cdd::TokenScanner.single_quote_literal("  #{name} (#{scheme['type']})")}\n"
          if scheme['type'] == 'oauth2'
            scopes_str = scheme.dig('flows', 'implicit', 'scopes')&.keys&.join(',')
            out += "  puts #{Cdd::TokenScanner.single_quote_literal("  OAuth Scopes: #{scopes_str}")}\n"
          end
        end
        out
      end

      # Emits schema help lines for `print_help`.
      #
      # @param schemas [Hash, nil] schemas component map
      # @return [String] Ruby puts statements
      def self.emit_help_schemas(schemas)
        return '' unless schemas

        out = "  puts 'Schemas Available:'\n"
        schemas.each do |name, schema|
          out += "  puts #{Cdd::TokenScanner.single_quote_literal("  #{name}")}\n"
          next unless schema['discriminator']

          prop_name = schema['discriminator']['propertyName']
          out += "  puts #{Cdd::TokenScanner.single_quote_literal("    Discriminator: #{prop_name}")}\n"
          if schema['discriminator']['mapping']
            map_json = schema['discriminator']['mapping'].to_json
            out += "  puts #{Cdd::TokenScanner.single_quote_literal("    Mapping: #{map_json}")}\n"
          end
        end
        out
      end

      # Emits path operation help lines for `print_help`.
      #
      # @param paths [Hash, nil] OpenAPI paths map
      # @return [String] Ruby puts statements
      def self.emit_help_paths(paths)
        return '' unless paths

        out = ''
        paths.each do |path, methods|
          methods.each do |method, details|
            operation_id = Cdd::TokenScanner.operation_id_for(method, path, details, collapse: false)
            summary = details['summary'] ? " - #{details['summary']}" : ''
            out += "  puts #{Cdd::TokenScanner.single_quote_literal("  #{operation_id}#{summary}")}\n"
            details['parameters']&.each do |param|
              req = param['required'] ? '*' : ''
              param_lit = Cdd::TokenScanner.single_quote_literal("    --#{param['name']} [#{param['in']}] #{req}")
              out += "  puts #{param_lit}\n"
            end
          end
        end
        out
      end

      # Returns the shared MCP JSON-RPC `elsif` branches for standard stubbed MCP methods.
      #
      # @param indent [String] leading whitespace indentation
      # @return [String] shared Ruby `elsif` branch lines
      def self.common_mcp_branch_lines(indent = '      ')
        "#{indent}elsif %w[ping logging/setLevel resources/subscribe resources/unsubscribe].include?(req['method'])\n" \
          "#{indent}  resp[:result] = {}\n" \
          "#{indent}elsif req['method'] == 'roots/list'\n" \
          "#{indent}  resp[:result] = { roots: [] }\n" \
          "#{indent}elsif req['method'] == 'resources/templates/list'\n" \
          "#{indent}  resp[:result] = { resourceTemplates: [] }\n" \
          "#{indent}elsif req['method'] == 'sampling/createMessage'\n" \
          "#{indent}  resp[:result] = { role: 'assistant', model: 'stub-model', " \
          "content: { type: 'text', text: 'sampled' } }\n" \
          "#{indent}elsif req['method'] == 'completion/complete'\n" \
          "#{indent}  resp[:result] = { completion: { values: [], total: 0, hasMore: false } }"
      end

      # Emits the `when 'mcp'` stdio JSON-RPC server branch using safe Open3 subprocess execution.
      #
      # @param openapi [Hash] parsed OpenAPI specification
      # @param arazzo [Hash, nil] optional parsed Arazzo specification
      # @return [String] Ruby source code for the MCP branch
      def self.emit_mcp_loop(openapi, arazzo = nil)
        info = openapi['info'] || {}
        tools_json = build_mcp_tools(openapi, arazzo).to_json
        docs_text = "# #{info['title'] || 'API'} Docs\n\n#{info['description'] || ''}"
        common_branches = common_mcp_branch_lines('      ')
        <<~RUBY
          command = ARGV.shift
          case command
          when 'mcp'
            require 'json'
            require 'open3'
            # Starting MCP server on stdio
            loop do
              line = $stdin.gets
              break if line.nil?
              next if line.strip.empty?
              begin
                req = JSON.parse(line)
                if req['id'].nil?
                  next
                end
                resp = { jsonrpc: '2.0', id: req['id'], result: { _meta: {} } }
                if req['method'] == 'initialize'
                  resp[:result] = { capabilities: { tools: { listChanged: true }, resources: { subscribe: true, listChanged: true }, prompts: { listChanged: true }, logging: {}, experimental: {}, roots: { listChanged: true }, sampling: {} }, serverInfo: { name: 'sdk-cli-mcp', version: '1.0.0' }, protocolVersion: '2024-11-05', instructions: '' }
          #{common_branches}
                elsif req['method'] == 'prompts/list'
                  resp[:result] = { prompts: [{ name: 'api_help', description: 'Help for API', arguments: [] }] }
                elsif req['method'] == 'prompts/get'
                  name = req.dig('params', 'name')
                  resp[:result] = name == 'api_help' ? { description: 'API Help', messages: [{ role: 'user', content: { type: 'text', text: 'How do I use this API?' } }] } : { messages: [] }
                elsif req['method'] == 'resources/list'
                  resp[:result] = { resources: [{ uri: 'mcp://api/docs', name: 'API Documentation', mimeType: 'text/markdown' }] }
                elsif req['method'] == 'resources/read'
                  uri = req.dig('params', 'uri')
                  resp[:result] = uri == 'mcp://api/docs' ? { contents: [{ uri: uri, mimeType: 'text/markdown', text: #{docs_text.inspect} }] } : { contents: [] }
                elsif req['method'] == 'tools/list'
                  resp[:result] = { tools: #{tools_json} }
                elsif req['method'] == 'tools/call'
                  tool_name = req.dig('params', 'name').to_s
                  args = req.dig('params', 'arguments') || {}
                  cmd_args = args.flat_map { |k, v| ["--\#{k}", v.to_s] }
                  out, _status = Open3.capture2e('ruby', __FILE__, tool_name, *cmd_args)
                  resp[:result] = { content: [{ type: 'text', text: out }] }
                else
                  resp = { jsonrpc: '2.0', id: req['id'], error: { code: -32601, message: 'Method not found' } }
                end
                $stdout.puts JSON.generate(resp)
                $stdout.flush
              rescue JSON::ParserError => e
                log_msg = { jsonrpc: '2.0', method: 'notifications/message', params: { level: 'error', logger: 'mcp-server', data: e.message } }
                $stdout.puts JSON.generate(log_msg)
                $stdout.puts JSON.generate({ jsonrpc: '2.0', error: { code: -32700, message: 'Parse error' } })
                $stdout.flush
              end
            end
        RUBY
      end

      # Emits `when '<operation_id>'` and `when 'workflow'` command branches.
      #
      # @param openapi [Hash] parsed OpenAPI specification
      # @param arazzo [Hash, nil] optional parsed Arazzo specification
      # @return [String] Ruby case branches and closing `end`
      def self.emit_command_branches(openapi, arazzo = nil)
        out = ''
        openapi['paths']&.each do |path, methods|
          methods.each do |method, details|
            out += emit_single_command_branch(path, method, details)
          end
        end
        if arazzo.is_a?(Hash) && arazzo['workflows'].is_a?(Array) && !arazzo['workflows'].empty?
          out += emit_workflow_command_branches(arazzo['workflows'])
        end
        "#{out}else\n  puts \"Unknown command: \#{command}\"\nend\n"
      end

      # Emits `when 'workflow'` and individual `when '<workflow_id>'` branches.
      #
      # @param workflows [Array<Hash>] Arazzo workflows list
      # @return [String] Ruby `when` branch code
      def self.emit_workflow_command_branches(workflows)
        ids = workflows.map { |w| w['workflowId'] }
        out = "when 'workflow'\n  sub = ARGV.shift\n"
        out += "  if sub == 'list'\n    puts #{ids.join(', ').inspect}\n"
        out += "  elsif sub == 'run'\n    wf_id = ARGV.shift\n    puts \"Running workflow \#{wf_id}\"\n  end\n"
        workflows.each do |workflow|
          wf_id = workflow['workflowId']
          wf_lit = Cdd::TokenScanner.single_quote_literal(wf_id)
          msg_lit = Cdd::TokenScanner.single_quote_literal("Running workflow #{wf_id}")
          out += "when #{wf_lit}\n  puts #{msg_lit}\n"
        end
        out
      end

      # Emits a single `when '<operation_id>'` branch.
      #
      # @param path [String] endpoint path
      # @param method [String] HTTP verb
      # @param details [Hash] OpenAPI operation details
      # @return [String] Ruby `when` branch code
      def self.emit_single_command_branch(path, method, details)
        operation_id = Cdd::TokenScanner.operation_id_for(method, path, details, collapse: false)
        op_lit = Cdd::TokenScanner.single_quote_literal(operation_id)
        call_lit = Cdd::TokenScanner.single_quote_literal("Calling #{method.upcase} #{path}")
        out = "when #{op_lit}\n  puts #{call_lit}\n"
        out += "  # External Docs: #{details.dig('externalDocs', 'url')}\n" if details['externalDocs']
        out += "  # Tags: #{details['tags'].join(', ')}\n" if details['tags']
        out += emit_branch_request_body_comments(details['requestBody']) if details['requestBody']
        out += emit_branch_response_comments(details['responses']) if details['responses']
        out += "  # Callbacks: #{details['callbacks'].keys.join(',')}\n" if details['callbacks']
        out
      end

      # Emits request body comment lines for a CLI command branch.
      #
      # @param request_body [Hash] OpenAPI requestBody hash
      # @return [String] comment lines
      def self.emit_branch_request_body_comments(request_body)
        out = "  # Body required: #{request_body['required']}\n"
        request_body['content']&.each do |mt, mtdetails|
          out += "  # Accepts #{mt}\n"
          out += "  # Example: #{mtdetails['examples'].keys.first}\n" if mtdetails['examples']
          out += "  # Encoding: #{mtdetails['encoding'].keys.join(',')}\n" if mtdetails['encoding']
        end
        out
      end

      # Emits response comment lines for a CLI command branch.
      #
      # @param responses [Hash] OpenAPI responses map
      # @return [String] comment lines
      def self.emit_branch_response_comments(responses)
        out = ''
        responses.each do |status, resp|
          out += "  # Expects #{status}: #{resp['description']}\n"
          out += "  # Returns headers: #{resp['headers'].keys.join(',')}\n" if resp['headers']
          resp['content']&.each_key { |mt| out += "  # Returns #{mt}\n" }
          out += "  # Links: #{resp['links'].keys.join(',')}\n" if resp['links']
        end
        out
      end

      # Writes the generated `sdk_cli.rb` and optional test/mock scaffolding to `options[:output]`.
      #
      # @param options [Hash] CLI generation options
      # @param openapi [Hash] parsed OpenAPI specification
      # @param ruby_code [String] generated CLI script content
      # @return [void]
      def self.write_cli_artifacts(options, openapi, ruby_code)
        FileUtils.mkdir_p(options[:output])
        Cdd::Scaffolding.generate(options, 'sdk_cli')
        File.write(File.join(options[:output], 'sdk_cli.rb'), ruby_code)
        return unless options[:tests]

        spec_dir = File.join(options[:output], 'spec')
        FileUtils.mkdir_p(spec_dir)
        File.write(File.join(spec_dir, 'integration_spec.rb'), emit_cli_integration_spec(openapi))

        ir = Cdd::IR.new(openapi)
        tests_code = "# frozen_string_literal: true\n\nrequire 'minitest'\nrequire_relative 'sdk_cli'\n\n" \
                     "#{Cdd::Tests::Emitter.emit(ir)}"
        File.write(File.join(options[:output], 'tests.rb'), tests_code)
        mocks_code = "# frozen_string_literal: true\n\n#{Cdd::Mocks::Emitter.emit(ir)}"
        File.write(File.join(options[:output], 'mocks.rb'), mocks_code)
      end

      # Generates the RSpec integration test suite for the CLI.
      #
      # @param openapi [Hash] parsed OpenAPI specification
      # @return [String] RSpec test file content
      def self.emit_cli_integration_spec(openapi)
        out = <<~RUBY
          # frozen_string_literal: true

          require 'rspec'
          require 'open3'

          RSpec.shared_context 'server fixture' do |server_flags|
            before(:all) do
              @server_pid = spawn('ruby ../../generated_server/server.rb -p 8080 ' + server_flags)
              sleep 2
            end
            after(:all) do
              Process.kill('TERM', @server_pid) rescue nil
              Process.wait(@server_pid) rescue nil
            end
          end

          RSpec.describe 'Client CLI' do
        RUBY

        sorted_paths = []
        (openapi['paths'] || {}).each do |path, methods|
          methods.each do |method, details|
            operation_id = Cdd::TokenScanner.operation_id_for(method, path, details, collapse: false)
            param_count = (details['parameters'] || []).size
            sorted_paths << { operation_id: operation_id, score: path.count('/') + param_count }
          end
        end
        sorted_paths.sort_by! { |p| p[:score] }

        { 'Category 2: Stub Tests' => '', 'Category 3: Stateful Ephemeral Tests' => '--ephemeral',
          'Category 4: Seeded Mock Tests' => '--ephemeral --seed' }.each do |cat_name, flags|
          out += "  context '#{cat_name}' do\n    include_context 'server fixture', '#{flags}'\n\n"
          sorted_paths.each do |p|
            out += "    it 'can call #{p[:operation_id]}' do\n"
            out += "      out, _status = Open3.capture2e('ruby', '../sdk_cli.rb', '#{p[:operation_id]}')\n"
            out += "      expect(out).to include('Calling')\n    end\n\n"
          end
          out += "  end\n\n"
        end
        "#{out}end\n\n"
      end
    end
  end
end
