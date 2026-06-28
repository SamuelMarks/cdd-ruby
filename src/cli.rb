# frozen_string_literal: true

require 'optparse'
require 'json'
require 'fileutils'
require_relative 'cdd'
require_relative 'server'

# CDD Module for the CLI
module CDD
  # Typed configuration for programmatic SDK invocation
  class Config
    attr_accessor :subcommand, :input, :output, :input_dir, :no_imports, :no_wrapping,
                  :no_github_actions, :no_installable_package, :tests, :mcp, :truth,
                  :with_ephemeral, :with_seed, :port, :listen

    # Initializes the configuration
    # @param opts [Hash] configuration options
    def initialize(opts = {})
      opts.each { |k, v| send("#{k}=", v) if respond_to?("#{k}=") }
    end

    # Converts the configuration to an array of arguments
    # @return [Array<String>] command line arguments
    def to_a
      args = []
      args << subcommand.to_s if subcommand
      args << '-i' << input.to_s if input
      args << '-o' << output.to_s if output
      args << '-d' << input_dir.to_s if input_dir
      args << '--no-imports' if no_imports
      args << '--no-wrapping' if no_wrapping
      args << '--no-github-actions' if no_github_actions
      args << '--no-installable-package' if no_installable_package
      args << '--tests' if tests
      args << '--mcp' if mcp
      if truth
        args << '--truth'
        args << truth.to_s
      end
      args << '--with-ephemeral' if with_ephemeral
      args << '--with-seed' if with_seed
      if port
        args << '-p'
        args << port.to_s
      end
      if listen
        args << '-l'
        args << listen.to_s
      end
      args
    end
  end

  # The CLI module handles command line parsing and orchestration
  module CLI
    class << self
      # Helper to get arguments from options or environment variables
      # @param options [Hash] the parsed options
      # @param key [Symbol] the option key
      # @param env_key [String] the fallback environment variable
      # @param default [String, nil] the fallback default value
      # @return [String, nil] the value
      def get_arg(options, key, env_key, default = nil)
        options.key?(key) ? options[key] : (ENV[env_key] || default)
      end

      # Prints the CLI help message
      # @return [void]
      def print_help
        puts <<~HELP
          cdd-ruby CLI
          Usage:
            cdd-ruby [subcommand] [options]

          Subcommands:
            from_openapi                   Generate code from an OpenAPI specification.
            to_openapi                     Generate an OpenAPI specification from source code.
            to_docs_json                   Generate JSON documentation with code snippets for an OpenAPI specification.
            serve_json_rpc                 Expose CLI interface as a JSON-RPC server.
            mcp                            Run the generator as an MCP server over stdio.
            sync                           Synchronize an OpenAPI specification with source code.

          Options:
            -h, --help                     Show this help message
            -v, --version                  Show version information
            -p, --port <port>              Port for the JSON-RPC server
            -l, --listen <address>         Host/IP to listen on for the JSON-RPC server

          Examples:
            cdd-ruby serve_json_rpc [--wasi] [-p <port>] [-l <listen>]
            cdd-ruby from_openapi to_sdk_cli -i <spec.json> [-o <target_directory>] [--no-github-actions] [--no-installable-package] [--tests] [--mcp]
            cdd-ruby from_openapi to_sdk -i <spec.json> [-o <target_directory>] [--no-github-actions] [--no-installable-package] [--tests] [--mcp]
            cdd-ruby from_openapi to_server -i <spec.json> [-o <target_directory>]
            cdd-ruby to_openapi -i <path/to/code> [-o <spec.json>]
            cdd-ruby to_docs_json [--no-imports] [--no-wrapping] -i <spec.json> [-o <docs.json>]
        HELP
      end

      # Prints help for from_openapi
      # @return [void]
      def print_from_openapi_help
        puts <<~HELP
          cdd-ruby from_openapi - Generate code from an OpenAPI specification.
          Usage:
            cdd-ruby from_openapi [target] [options]

          Targets:
            to_sdk_cli    Generate a client SDK and a corresponding CLI.
            to_sdk        Generate a client SDK.
            to_server     Generate server boilerplate, models, and routing logic.

          Options:
            -i, --input <spec>             Path to the OpenAPI specification file
            -o, --output <dir>             Destination path for generation (default: current directory)
            -d, --input-dir <dir>          Directory of input specifications
            --no-github-actions            Disable GitHub Actions workflow generation
            --no-installable-package       Disable installable package generation
            --tests                        Generate RSpec test scaffolding
            --mcp                          Include Model Context Protocol support
            --with-ephemeral               Enable ephemeral code generation
            --with-seed                    Include seed data in generation
            -h, --help                     Show this help message
        HELP
      end

      # Prints help for to_openapi
      # @return [void]
      def print_to_openapi_help
        puts <<~HELP
          cdd-ruby to_openapi - Generate an OpenAPI specification from source code.
          Usage:
            cdd-ruby to_openapi -i <path/to/code> [-o <spec.json>]

          Options:
            -i, --input <path>             Path to the source code directory or file to parse
            -o, --output <path>            Destination path for the generated OpenAPI spec (default: spec.json)
            -h, --help                     Show this help message
        HELP
      end

      # Prints help for to_docs_json
      # @return [void]
      def print_to_docs_json_help
        puts <<~HELP
          cdd-ruby to_docs_json - Generate JSON documentation with code snippets for an OpenAPI specification.
          Usage:
            cdd-ruby to_docs_json [options] -i <spec.json> [-o <docs.json>]

          Options:
            -i, --input <spec>             Path to the OpenAPI specification file
            -o, --output <path>            Destination path for the generated JSON docs (default: docs.json)
            --no-imports                   Disable import statements in the generated documentation
            --no-wrapping                  Disable line wrapping in the generated documentation
            -h, --help                     Show this help message
        HELP
      end

      # Prints help for serve_json_rpc
      # @return [void]
      def print_serve_json_rpc_help
        puts <<~HELP
          cdd-ruby serve_json_rpc - Expose CLI interface as a JSON-RPC server.
          Usage:
            cdd-ruby serve_json_rpc [options]

          Options:
            -p, --port <port>              Port to listen on (default: 8080)
            -l, --listen <address>         Address to bind to (default: 127.0.0.2)
            -h, --help                     Show this help message
        HELP
      end

      # Prints help for mcp
      # @return [void]
      def print_mcp_help
        puts <<~HELP
          cdd-ruby mcp - Run the generator as an MCP server over stdio.
          Usage:
            cdd-ruby mcp [options]

          Options:
            -h, --help                     Show this help message
        HELP
      end

      # Prints help for sync
      # @return [void]
      def print_sync_help
        puts <<~HELP
          cdd-ruby sync - Synchronize an OpenAPI specification with source code.
          Usage:
            cdd-ruby sync [options] -i <filepath> --truth <class|activerecord|function>

          Options:
            -i, --input <filepath>         Path to the input file
            --truth <type>                 The source of truth for the synchronization (class, activerecord, function)
            -h, --help                     Show this help message
        HELP
      end

      # Generate code from an OpenAPI specification.
      # @param config [CDD::Config, Array<String>] programmatic configuration or raw arguments
      # @return [Integer] the exit code
      def generate_from_openapi(config)
        args = config.is_a?(CDD::Config) ? config.to_a : config
        run(['from_openapi'] + args)
      end

      # Generate an OpenAPI specification from source code.
      # @param config [CDD::Config, Array<String>] programmatic configuration or raw arguments
      # @return [Integer] the exit code
      def generate_to_openapi(config)
        args = config.is_a?(CDD::Config) ? config.to_a : config
        run(['to_openapi'] + args)
      end

      # Generate JSON documentation with code snippets for an OpenAPI specification.
      # @param config [CDD::Config, Array<String>] programmatic configuration or raw arguments
      # @return [Integer] the exit code
      def generate_docs_json(config)
        args = config.is_a?(CDD::Config) ? config.to_a : config
        run(['to_docs_json'] + args)
      end

      # Expose CLI interface as a JSON-RPC server.
      # @param config [CDD::Config, Array<String>] programmatic configuration or raw arguments
      # @return [Integer] the exit code
      def serve_json_rpc(config)
        args = config.is_a?(CDD::Config) ? config.to_a : config
        run(['serve_json_rpc'] + args)
      end

      # Runs the CLI loop
      # @param argv [Array<String>] the command line arguments
      # @return [Integer] the exit code
      def run(argv)
        if argv.empty? || argv == ['-h'] || argv == ['--help']
          print_help
          return 0
        end

        if argv.include?('-v') || argv.include?('--version')
          puts '0.0.3'
          return 0
        end

        command = argv.shift

        if argv.include?('-h') || argv.include?('--help')
          case command
          when 'from_openapi'
            print_from_openapi_help
          when 'to_openapi'
            print_to_openapi_help
          when 'to_docs_json'
            print_to_docs_json_help
          when 'serve_json_rpc'
            print_serve_json_rpc_help
          when 'mcp'
            print_mcp_help
          when 'sync'
            print_sync_help
          else
            print_help
          end
          return 0
        end

        options = {}

        while argv.any? && argv[0].start_with?('-')
          arg = argv.shift
          case arg
          when '-i', '--input' then options[:i] = argv.shift
          when '-o', '--output' then options[:o] = argv.shift
          when '-d', '--input-dir' then options[:input_dir] = argv.shift
          when '--no-imports' then options[:no_imports] = true
          when '--no-wrapping' then options[:no_wrapping] = true
          when '--no-github-actions' then options[:no_github_actions] = true
          when '--no-installable-package' then options[:no_installable_package] = true
          when '--tests' then options[:tests] = true
          when '--mcp' then options[:mcp] = true
          when '--truth' then options[:truth] = argv.shift
          when '--with-ephemeral' then options[:with_ephemeral] = true
          when '--with-seed' then options[:with_seed] = true
          when '-p', '--port' then options[:port] = argv.shift
          when '-l', '--listen' then options[:listen] = argv.shift
          end
        end

        case command
        when 'mcp'
          require 'json'
          loop do
            line = $stdin.gets
            break if line.nil?
            next if line.strip.empty?

            begin
              req = JSON.parse(line)

              if req['id'].nil?
                # Notification handling
                if req['method'] == 'notifications/cancelled'
                  # Cancelled request
                end
                next
              end

              resp = { jsonrpc: '2.0', id: req['id'], result: { _meta: {} } }
              case req['method']
              when 'initialize'
                resp[:result] = { capabilities: { tools: { listChanged: true }, prompts: { listChanged: true }, logging: {}, resources: { subscribe: true, listChanged: true }, experimental: {}, roots: { listChanged: true }, sampling: {} }, serverInfo: { name: 'cdd-ruby-mcp', version: '1.0.0' }, protocolVersion: '2024-11-05' }
              when 'tools/list'
                resp[:result] = {
                  tools: [
                    { name: 'generate_from_openapi', description: 'Generate code from OpenAPI', inputSchema: { type: 'object', properties: { subcommand: { type: 'string' }, input: { type: 'string' }, output: { type: 'string' } }, required: %w[subcommand input] } },
                    { name: 'generate_to_openapi', description: 'Extract OpenAPI schema from code', inputSchema: { type: 'object', properties: { input: { type: 'string' }, output: { type: 'string' } }, required: ['input'] } },
                    { name: 'inspect_schema', description: 'Inspect an OpenAPI JSON schema file', inputSchema: { type: 'object', properties: { filepath: { type: 'string' } }, required: ['filepath'] } }
                  ]
                }
              when 'tools/call'
                tname = req.dig('params', 'name')
                targs = req.dig('params', 'arguments') || {}

                if tname == 'inspect_schema'
                  begin
                    schema = JSON.parse(File.read(targs['filepath']))
                    summary = "Schema: #{schema.dig('info', 'title') || 'Unknown'} #{schema.dig('info', 'version') || ''}\n"
                    summary += "Paths: #{schema['paths']&.keys&.join(', ') || 'None'}\n"
                    summary += "Components: #{schema.dig('components', 'schemas')&.keys&.join(', ') || 'None'}\n"
                    resp[:result] = { content: [{ type: 'text', text: summary }] }
                  rescue StandardError => e
                    resp = { jsonrpc: '2.0', id: req['id'], error: { code: -32_603, message: "Internal error: #{e.message}" } }
                    log_msg = { jsonrpc: '2.0', method: 'notifications/message', params: { level: 'error', logger: 'mcp-server', data: e.message } }
                    $stdout.puts JSON.generate(log_msg)
                  end
                elsif %w[generate_from_openapi generate_to_openapi].include?(tname)
                  require 'stringio'
                  old_stdout = $stdout
                  $stdout = StringIO.new
                  begin
                    if tname == 'generate_from_openapi'
                      run(['from_openapi', targs['subcommand'], '-i', targs['input'], '-o', targs['output'] || '.'])
                    elsif tname == 'generate_to_openapi'
                      run(['to_openapi', '-i', targs['input'], '-o', targs['output'] || 'spec.json'])
                    end
                  ensure
                    $stdout = old_stdout
                  end
                  resp[:result] = { content: [{ type: 'text', text: 'Generated successfully' }] }
                else
                  resp = { jsonrpc: '2.0', id: req['id'], error: { code: -32_601, message: 'Method not found' } }
                end
              when 'prompts/list'
                resp[:result] = { prompts: [{ name: 'generate_docs', description: 'Generate standard documentation', arguments: [{ name: 'filepath', description: 'Path to source code', required: true }] }] }
              when 'prompts/get'
                pname = req.dig('params', 'name')
                pargs = req.dig('params', 'arguments') || {}
                resp[:result] = { description: 'Generate docs prompt', messages: [{ role: 'user', content: { type: 'text', text: "Please generate docs for #{pargs['filepath']}" } }] } if pname == 'generate_docs'
              when 'resources/list'
                resp[:result] = { resources: [{ uri: 'mcp://cdd/docs', name: 'CDD Documentation', mimeType: 'text/markdown' }] }
              when 'resources/read'
                ruri = req.dig('params', 'uri')
                resp[:result] = { contents: [{ uri: ruri, mimeType: 'text/markdown', text: '# CDD Docs' }] } if ruri == 'mcp://cdd/docs'
              when 'resources/templates/list'
                resp[:result] = { resourceTemplates: [] }
              when 'roots/list'
                resp[:result] = { roots: [] }
              when 'resources/subscribe', 'resources/unsubscribe', 'logging/setLevel', 'ping'
                resp[:result] = {} # Acknowledge requests
              when 'sampling/createMessage'
                resp[:result] = { role: 'assistant', model: 'stub-model', content: { type: 'text', text: 'sampled' } }
              when 'completion/complete'
                resp[:result] = { completion: { values: [], total: 0, hasMore: false } }
              else
                resp = { jsonrpc: '2.0', id: req['id'], error: { code: -32_601, message: 'Method not found' } }
              end

              $stdout.puts JSON.generate(resp)
              $stdout.flush
            rescue JSON::ParserError
              $stdout.puts JSON.generate({ jsonrpc: '2.0', error: { code: -32_700, message: 'Parse error' } })
              $stdout.flush
            end
          end
          0

        when 'sync'

          input = get_arg(options, :i, 'CDD_INPUT')
          truth = get_arg(options, :truth, 'CDD_TRUTH')

          if input.nil? || truth.nil?
            puts 'Error: Missing -i <filepath> or --truth <class|activerecord|function>'
            return 1
          end

          require_relative 'sync'
          Cdd::Sync.sync(input, truth)
          puts 'Synchronization complete.'
          0

        when 'to_openapi'
          file = get_arg(options, :i, 'CDD_INPUT')
          out = get_arg(options, :o, 'CDD_OUTPUT', 'spec.json')

          if file.nil?
            puts 'Error: Missing -i <filepath> or --input <filepath>'
            return 1
          end
          target_files = if File.directory?(file)
                           Dir.glob(File.join(file, '**', '*.rb')).reject do |f|
                             f.include?('/spec/') || f.include?('/tests/') || f.include?('/vendor/') || f.include?('/.bundle/') || f.end_with?('_spec.rb') || f.end_with?('_test.rb')
                           end
                         else
                           [file]
                         end

          result = Cdd::Parser.parse(target_files)

          if out == '-'
            puts result
          else
            FileUtils.mkdir_p(File.dirname(out))
            File.write(out, result)
          end
          0

        when 'to_docs_json'
          input = get_arg(options, :i, 'CDD_INPUT')
          out = get_arg(options, :o, 'CDD_OUTPUT', 'docs.json')
          no_imports = get_arg(options, :no_imports, 'CDD_NO_IMPORTS', false)
          no_wrapping = get_arg(options, :no_wrapping, 'CDD_NO_WRAPPING', false)

          if input.nil?
            puts 'Error: Missing -i <filepath>'
            return 1
          end

          result = Cdd::DocsJson::Emitter.emit(input, no_imports: no_imports, no_wrapping: no_wrapping)
          if out == '-'
            puts result
          else
            FileUtils.mkdir_p(File.dirname(out))
            File.write(out, result)
          end
          0

        when 'from_openapi'
          subcommand = argv.shift

          while argv.any? && argv[0].start_with?('-')
            arg = argv.shift
            case arg
            when '-i', '--input' then options[:i] = argv.shift
            when '-o', '--output' then options[:o] = argv.shift
            when '-d', '--input-dir' then options[:input_dir] = argv.shift
            when '--no-github-actions' then options[:no_github_actions] = true
            when '--no-installable-package' then options[:no_installable_package] = true
            when '--tests' then options[:tests] = true
            when '--mcp' then options[:mcp] = true
            when '--with-ephemeral' then options[:with_ephemeral] = true
            when '--with-seed' then options[:with_seed] = true
            end
          end

          input = get_arg(options, :i, 'CDD_INPUT')
          input_dir = get_arg(options, :input_dir, 'CDD_INPUT_DIR')
          out = get_arg(options, :o, 'CDD_OUTPUT', Dir.pwd)
          no_gh = get_arg(options, :no_github_actions, 'CDD_NO_GITHUB_ACTIONS')
          no_pkg = get_arg(options, :no_installable_package, 'CDD_NO_INSTALLABLE_PACKAGE')
          tests = get_arg(options, :tests, 'CDD_TESTS')
          mcp = get_arg(options, :mcp, 'CDD_MCP')
          with_eph = get_arg(options, :with_ephemeral, 'CDD_WITH_EPHEMERAL')
          with_seed = get_arg(options, :with_seed, 'CDD_WITH_SEED')

          unless input || input_dir
            puts 'Error: Missing -i <filepath> or -d <dir> or --input-dir <dir>'
            return 1
          end

          emitter_options = {
            input: input,
            input_dir: input_dir,
            output: out,
            no_github_actions: no_gh,
            no_installable_package: no_pkg,
            tests: tests,
            mcp: mcp,
            with_ephemeral: with_eph,
            with_seed: with_seed
          }

          case subcommand
          when 'to_sdk_cli'
            puts Cdd::Emitter.emit_sdk_cli(emitter_options)
          when 'to_sdk'
            puts Cdd::Emitter.emit_sdk(emitter_options)
          when 'to_server'
            puts Cdd::Emitter.emit_server(emitter_options)
          else
            puts "Unknown from_openapi subcommand: #{subcommand}"
            return 1
          end
          0

        when 'serve_json_rpc'

          port = get_arg(options, :port, 'CDD_PORT', '8080')
          listen = get_arg(options, :listen, 'CDD_LISTEN', '127.0.0.2')
          Cdd::Server.start(listen, port)
          0
        else
          puts "Error: Unknown or incomplete command: #{command}"
          print_help
          1
        end
      end
    end
  end
end
