# frozen_string_literal: true

require 'optparse'
require 'json'
require 'fileutils'
require_relative 'cdd'
require_relative 'server'

# Core namespace for the CDD Ruby compiler and OpenAPI toolchain.
module Cdd
  # Typed configuration for programmatic SDK and CLI invocation.
  class Config
    # Valid configuration attribute symbols.
    ATTRIBUTES = %i[
      subcommand input output input_dir arazzo no_imports no_wrapping
      no_github_actions no_installable_package tests mcp truth
      with_ephemeral with_seed port listen
    ].freeze

    # Ordered specification of configuration attributes to CLI flags (`[attr, flag, is_boolean]`).
    CLI_OPTION_SPECS = [
      [:input, '-i', false],
      [:output, '-o', false],
      [:input_dir, '-d', false],
      [:arazzo, '--arazzo', false],
      [:no_imports, '--no-imports', true],
      [:no_wrapping, '--no-wrapping', true],
      [:no_github_actions, '--no-github-actions', true],
      [:no_installable_package, '--no-installable-package', true],
      [:tests, '--tests', true],
      [:mcp, '--mcp', true],
      [:truth, '--truth', false],
      [:with_ephemeral, '--with-ephemeral', true],
      [:with_seed, '--with-seed', true],
      [:port, '-p', false],
      [:listen, '-l', false]
    ].freeze

    # Alias lookup keys for each configuration attribute.
    ATTRIBUTE_ALIASES = {
      subcommand: %i[subcommand],
      input: %i[input i],
      output: %i[output o],
      input_dir: %i[input_dir d],
      arazzo: %i[arazzo],
      no_imports: %i[no_imports],
      no_wrapping: %i[no_wrapping],
      no_github_actions: %i[no_github_actions],
      no_installable_package: %i[no_installable_package],
      tests: %i[tests],
      mcp: %i[mcp],
      truth: %i[truth],
      with_ephemeral: %i[with_ephemeral],
      with_seed: %i[with_seed],
      port: %i[port],
      listen: %i[listen]
    }.freeze

    # Configuration attributes for CLI and SDK invocation.
    # @return [Object, nil]
    attr_accessor :subcommand, :input, :output, :input_dir, :arazzo, :no_imports, :no_wrapping,
                  :no_github_actions, :no_installable_package, :tests, :mcp, :truth,
                  :with_ephemeral, :with_seed, :port, :listen

    # Initializes the configuration with validated option keys.
    #
    # @param opts [Hash{Symbol, String => Object}] configuration options
    # @return [Cdd::Config]
    def initialize(opts = {})
      normalized = opts.transform_keys(&:to_sym)
      ATTRIBUTE_ALIASES.each do |attr, aliases|
        key = aliases.find { |k| normalized.key?(k) }
        instance_variable_set(:"@#{attr}", key ? normalized[key] : nil)
      end
    end

    # Reads a configuration attribute by key symbol or string for Hash-like compatibility.
    #
    # @param key [Symbol, String] attribute name
    # @return [Object, nil] attribute value
    def [](key)
      sym = key.to_sym
      return nil unless ATTRIBUTES.include?(sym)

      instance_variable_get(:"@#{sym}")
    end

    # Converts the configuration to a Hash with symbol keys.
    #
    # @return [Hash{Symbol => Object}] hash representation of the configuration
    def to_h
      ATTRIBUTES.each_with_object({}) do |attr, hash|
        val = instance_variable_get(:"@#{attr}")
        hash[attr] = val unless val.nil?
      end
    end

    # Converts the configuration to an array of CLI arguments.
    #
    # @return [Array<String>] command line arguments
    def to_a
      args = []
      args << subcommand.to_s if subcommand
      CLI_OPTION_SPECS.each do |attr, flag, is_bool|
        val = instance_variable_get(:"@#{attr}")
        next unless val

        is_bool ? (args << flag) : args.push(flag, val.to_s)
      end
      args
    end
  end

  # The CLI module handles command line parsing and orchestration.
  module CLI
    # CLI flags that consume a following argument value.
    VALUE_FLAGS = {
      '-i' => :i, '--input' => :i,
      '-o' => :o, '--output' => :o,
      '-d' => :input_dir, '--input-dir' => :input_dir,
      '--arazzo' => :arazzo,
      '--truth' => :truth,
      '-p' => :port, '--port' => :port,
      '-l' => :listen, '--listen' => :listen
    }.freeze

    # CLI flags that act as boolean switches.
    BOOLEAN_FLAGS = {
      '--no-imports' => :no_imports,
      '--no-wrapping' => :no_wrapping,
      '--no-github-actions' => :no_github_actions,
      '--no-installable-package' => :no_installable_package,
      '--tests' => :tests,
      '--mcp' => :mcp,
      '--with-ephemeral' => :with_ephemeral,
      '--with-seed' => :with_seed
    }.freeze

    # Built-in MCP tool definitions exposed by `cdd-ruby mcp`.
    MCP_TOOLS = [
      {
        name: 'generate_from_openapi',
        description: 'Generate code from OpenAPI',
        inputSchema: {
          type: 'object',
          properties: { subcommand: { type: 'string' }, input: { type: 'string' }, output: { type: 'string' } },
          required: %w[subcommand input]
        }
      },
      {
        name: 'generate_to_openapi',
        description: 'Extract OpenAPI schema from code',
        inputSchema: {
          type: 'object',
          properties: { input: { type: 'string' }, output: { type: 'string' } },
          required: ['input']
        }
      },
      {
        name: 'generate_from_arazzo',
        description: 'Generate code from Arazzo 1.1.0 specification',
        inputSchema: {
          type: 'object',
          properties: { subcommand: { type: 'string' }, input: { type: 'string' }, output: { type: 'string' } },
          required: %w[subcommand input]
        }
      },
      {
        name: 'generate_to_arazzo',
        description: 'Extract Arazzo 1.1.0 specification from code',
        inputSchema: {
          type: 'object',
          properties: { input: { type: 'string' }, output: { type: 'string' } },
          required: ['input']
        }
      },
      {
        name: 'inspect_schema',
        description: 'Inspect an OpenAPI or Arazzo JSON schema file',
        inputSchema: {
          type: 'object',
          properties: { filepath: { type: 'string' } },
          required: ['filepath']
        }
      }
    ].freeze

    # Common CLI options shared by `from_openapi` targets.
    FROM_OPENAPI_OPTIONS_TEXT = <<~OPTS.chomp
      Options:
        -i, --input <spec>             Path to the OpenAPI specification file
        -o, --output <dir>             Destination path for generation (default: current directory)
        -d, --input-dir <dir>          Directory of input specifications
        --arazzo <spec>                Path to an optional Arazzo 1.1.0 workflow specification file
        --no-github-actions            Disable GitHub Actions workflow generation
        --no-installable-package       Disable installable package generation
        --tests                        Generate Minitest test scaffolding
        --mcp                          Include Model Context Protocol support
        --with-ephemeral               Enable ephemeral code generation
        --with-seed                    Include seed data in generation
        -h, --help                     Show this help message
    OPTS

    # Common CLI options shared by `from_arazzo` targets.
    FROM_ARAZZO_OPTIONS_TEXT = <<~OPTS.chomp
      Options:
        -i, --input <spec>             Path to the Arazzo specification file
        -o, --output <dir>             Destination path for generation (default: current directory)
        -h, --help                     Show this help message
    OPTS

    # Help text templates keyed by subcommand/target identifier.
    HELP_TEXTS = {
      main: <<~HELP,
        cdd-ruby CLI
        Usage:
          cdd-ruby [subcommand] [options]

        Subcommands:
          from_openapi                   Generate code from an OpenAPI specification.
          to_openapi                     Generate an OpenAPI specification from source code.
          from_arazzo                    Generate code from an Arazzo 1.1.0 specification.
          to_arazzo                      Generate an Arazzo 1.1.0 specification from source code.
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
          cdd-ruby from_arazzo to_sdk -i <arazzo.json> [-o <target_directory>]
          cdd-ruby to_arazzo -i <path/to/code> [-o <arazzo.json>]
          cdd-ruby to_docs_json [--no-imports] [--no-wrapping] -i <spec.json> [-o <docs.json>]
      HELP
      from_openapi: <<~HELP,
        cdd-ruby from_openapi - Generate code from an OpenAPI specification.
        Usage:
          cdd-ruby from_openapi [target] [options]

        Targets:
          to_sdk_cli    Generate a client SDK and a corresponding CLI.
          to_sdk        Generate a client SDK.
          to_server     Generate server boilerplate, models, and routing logic.

        #{FROM_OPENAPI_OPTIONS_TEXT}
      HELP
      from_openapi_to_sdk_cli: <<~HELP,
        cdd-ruby from_openapi to_sdk_cli - Generate a client SDK and a corresponding CLI.
        Usage:
          cdd-ruby from_openapi to_sdk_cli -i <spec.json> [-o <target_directory>] [options]

        #{FROM_OPENAPI_OPTIONS_TEXT}
      HELP
      from_openapi_to_sdk: <<~HELP,
        cdd-ruby from_openapi to_sdk - Generate a client SDK.
        Usage:
          cdd-ruby from_openapi to_sdk -i <spec.json> [-o <target_directory>] [options]

        #{FROM_OPENAPI_OPTIONS_TEXT}
      HELP
      from_openapi_to_server: <<~HELP,
        cdd-ruby from_openapi to_server - Generate server boilerplate, models, and routing logic.
        Usage:
          cdd-ruby from_openapi to_server -i <spec.json> [-o <target_directory>] [options]

        #{FROM_OPENAPI_OPTIONS_TEXT}
      HELP
      to_openapi: <<~HELP,
        cdd-ruby to_openapi - Generate an OpenAPI specification from source code.
        Usage:
          cdd-ruby to_openapi -i <path/to/code> [-o <spec.json>]

        Options:
          -i, --input <path>             Path to the source code directory or file to parse
          -o, --output <path>            Destination path for the generated OpenAPI spec (default: spec.json)
          -h, --help                     Show this help message
      HELP
      from_arazzo: <<~HELP,
        cdd-ruby from_arazzo - Generate code from an Arazzo 1.1.0 specification.
        Usage:
          cdd-ruby from_arazzo [target] [options]

        Targets:
          to_sdk_cli    Generate a client SDK CLI workflow runner.
          to_sdk        Generate a client SDK with workflow orchestration.
          to_server     Generate server workflow engine and E2E test suites.

        #{FROM_ARAZZO_OPTIONS_TEXT}
      HELP
      from_arazzo_to_sdk_cli: <<~HELP,
        cdd-ruby from_arazzo to_sdk_cli - Generate a client SDK CLI workflow runner.
        Usage:
          cdd-ruby from_arazzo to_sdk_cli -i <arazzo.json> [-o <target_directory>] [options]

        #{FROM_ARAZZO_OPTIONS_TEXT}
      HELP
      from_arazzo_to_sdk: <<~HELP,
        cdd-ruby from_arazzo to_sdk - Generate a client SDK with workflow orchestration.
        Usage:
          cdd-ruby from_arazzo to_sdk -i <arazzo.json> [-o <target_directory>] [options]

        #{FROM_ARAZZO_OPTIONS_TEXT}
      HELP
      from_arazzo_to_server: <<~HELP,
        cdd-ruby from_arazzo to_server - Generate server workflow engine and E2E test suites.
        Usage:
          cdd-ruby from_arazzo to_server -i <arazzo.json> [-o <target_directory>] [options]

        #{FROM_ARAZZO_OPTIONS_TEXT}
      HELP
      to_arazzo: <<~HELP,
        cdd-ruby to_arazzo - Generate an Arazzo 1.1.0 specification from source code.
        Usage:
          cdd-ruby to_arazzo -i <path/to/code> [-o <arazzo.json>]

        Options:
          -i, --input <path>             Path to the source code directory or file to parse
          -o, --output <path>            Destination path for the generated Arazzo spec (default: arazzo.json)
          -h, --help                     Show this help message
      HELP
      to_docs_json: <<~HELP,
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
      serve_json_rpc: <<~HELP,
        cdd-ruby serve_json_rpc - Expose CLI interface as a JSON-RPC server.
        Usage:
          cdd-ruby serve_json_rpc [options]

        Options:
          -p, --port <port>              Port to listen on (default: 8080)
          -l, --listen <address>         Address to bind to (default: 127.0.0.2)
          -h, --help                     Show this help message
      HELP
      mcp: <<~HELP,
        cdd-ruby mcp - Run the generator as an MCP server over stdio.
        Usage:
          cdd-ruby mcp [options]

        Options:
          -h, --help                     Show this help message
      HELP
      sync: <<~HELP
        cdd-ruby sync - Synchronize an OpenAPI specification with source code.
        Usage:
          cdd-ruby sync [options] -i <filepath> --truth <class|activerecord|function>

        Options:
          -i, --input <filepath>         Path to the input file
          --truth <type>                 The source of truth for the synchronization (class, activerecord, function)
          -h, --help                     Show this help message
      HELP
    }.freeze

    # Help printer methods mixed into `Cdd::CLI` singleton class.
    module HelpPrinter
      # Prints the CLI help block registered under `key`.
      #
      # @param key [Symbol] help entry key in `HELP_TEXTS`
      # @return [void]
      def print_help_for(key)
        puts HELP_TEXTS.fetch(key)
      end

      # Prints the top-level CLI help message.
      # @return [void]
      def print_help = print_help_for(:main)

      # Prints help for `from_openapi`.
      # @return [void]
      def print_from_openapi_help = print_help_for(:from_openapi)

      # Prints help for `from_openapi to_sdk_cli`.
      # @return [void]
      def print_from_openapi_to_sdk_cli_help = print_help_for(:from_openapi_to_sdk_cli)

      # Prints help for `from_openapi to_sdk`.
      # @return [void]
      def print_from_openapi_to_sdk_help = print_help_for(:from_openapi_to_sdk)

      # Prints help for `from_openapi to_server`.
      # @return [void]
      def print_from_openapi_to_server_help = print_help_for(:from_openapi_to_server)

      # Prints help for `to_openapi`.
      # @return [void]
      def print_to_openapi_help = print_help_for(:to_openapi)

      # Prints help for `from_arazzo`.
      # @return [void]
      def print_from_arazzo_help = print_help_for(:from_arazzo)

      # Prints help for `from_arazzo to_sdk_cli`.
      # @return [void]
      def print_from_arazzo_to_sdk_cli_help = print_help_for(:from_arazzo_to_sdk_cli)

      # Prints help for `from_arazzo to_sdk`.
      # @return [void]
      def print_from_arazzo_to_sdk_help = print_help_for(:from_arazzo_to_sdk)

      # Prints help for `from_arazzo to_server`.
      # @return [void]
      def print_from_arazzo_to_server_help = print_help_for(:from_arazzo_to_server)

      # Prints help for `to_arazzo`.
      # @return [void]
      def print_to_arazzo_help = print_help_for(:to_arazzo)

      # Prints help for `to_docs_json`.
      # @return [void]
      def print_to_docs_json_help = print_help_for(:to_docs_json)

      # Prints help for `serve_json_rpc`.
      # @return [void]
      def print_serve_json_rpc_help = print_help_for(:serve_json_rpc)

      # Prints help for `mcp`.
      # @return [void]
      def print_mcp_help = print_help_for(:mcp)

      # Prints help for `sync`.
      # @return [void]
      def print_sync_help = print_help_for(:sync)
    end

    extend HelpPrinter

    class << self
      # Helper to get arguments from options or environment variables.
      #
      # @param options [Hash] the parsed options
      # @param key [Symbol] the option key
      # @param env_key [String] the fallback environment variable
      # @param default [String, Boolean, nil] the fallback default value
      # @return [Object, nil] the value
      def get_arg(options, key, env_key, default = nil)
        options.key?(key) ? options[key] : (ENV[env_key] || default)
      end

      # Generates code from an OpenAPI specification.
      #
      # @param config [Cdd::Config] programmatic configuration
      # @return [Integer] the exit code
      def generate_from_openapi(config)
        run(['from_openapi'] + config.to_a)
      end

      # Generates an OpenAPI specification from source code.
      #
      # @param config [Cdd::Config] programmatic configuration
      # @return [Integer] the exit code
      def generate_to_openapi(config)
        run(['to_openapi'] + config.to_a)
      end

      # Generates code from an Arazzo 1.1.0 specification.
      #
      # @param config [Cdd::Config] programmatic configuration
      # @return [Integer] the exit code
      def generate_from_arazzo(config)
        run(['from_arazzo'] + config.to_a)
      end

      # Generates an Arazzo 1.1.0 specification from source code.
      #
      # @param config [Cdd::Config] programmatic configuration
      # @return [Integer] the exit code
      def generate_to_arazzo(config)
        run(['to_arazzo'] + config.to_a)
      end

      # Generates JSON documentation with code snippets for an OpenAPI specification.
      #
      # @param config [Cdd::Config] programmatic configuration
      # @return [Integer] the exit code
      def generate_docs_json(config)
        run(['to_docs_json'] + config.to_a)
      end

      # Exposes the CLI interface as a JSON-RPC server.
      #
      # @param config [Cdd::Config] programmatic configuration
      # @return [Integer] the exit code
      def serve_json_rpc(config)
        run(['serve_json_rpc'] + config.to_a)
      end

      # Parses CLI flags from `argv` into `options` hash in place.
      #
      # @param argv [Array<String>] remaining CLI tokens
      # @param options [Hash{Symbol => Object}] target options hash
      # @return [void]
      def parse_options(argv, options)
        while argv.any? && argv[0].start_with?('-')
          arg = argv.shift
          if VALUE_FLAGS.key?(arg)
            options[VALUE_FLAGS[arg]] = argv.shift
          else
            options[BOOLEAN_FLAGS[arg]] = true
          end
        end
      end

      # Prints subcommand-specific help for `command` (and optional `target`).
      #
      # @param command [String, nil] CLI subcommand
      # @param target [String, nil] optional target subcommand
      # @return [Integer] exit code `0`
      def dispatch_help(command, target = nil)
        case command
        when 'from_openapi' then dispatch_from_openapi_help(target)
        when 'to_openapi' then print_to_openapi_help
        when 'from_arazzo' then dispatch_from_arazzo_help(target)
        when 'to_arazzo' then print_to_arazzo_help
        when 'to_docs_json' then print_to_docs_json_help
        when 'serve_json_rpc' then print_serve_json_rpc_help
        when 'mcp' then print_mcp_help
        when 'sync' then print_sync_help
        else print_help
        end
        0
      end

      # Prints target-specific or general help for `from_openapi`.
      #
      # @param target [String, nil] target subcommand (`to_sdk_cli`, `to_sdk`, `to_server`)
      # @return [void]
      def dispatch_from_openapi_help(target)
        case target
        when 'to_sdk_cli' then print_from_openapi_to_sdk_cli_help
        when 'to_sdk' then print_from_openapi_to_sdk_help
        when 'to_server' then print_from_openapi_to_server_help
        else print_from_openapi_help
        end
      end

      # Prints target-specific or general help for `from_arazzo`.
      #
      # @param target [String, nil] target subcommand (`to_sdk_cli`, `to_sdk`, `to_server`)
      # @return [void]
      def dispatch_from_arazzo_help(target)
        case target
        when 'to_sdk_cli' then print_from_arazzo_to_sdk_cli_help
        when 'to_sdk' then print_from_arazzo_to_sdk_help
        when 'to_server' then print_from_arazzo_to_server_help
        else print_from_arazzo_help
        end
      end

      # Runs the main CLI command dispatcher.
      #
      # @param argv [Array<String>] command line arguments
      # @return [Integer] exit code (`0` for success, `1` for error)
      def run(argv)
        if argv.empty? || argv == ['-h'] || argv == ['--help']
          print_help
          return 0
        end

        if argv.include?('-v') || argv.include?('--version')
          puts '0.0.4'
          return 0
        end

        command = argv.shift
        return dispatch_help(command, argv.first) if argv.include?('-h') || argv.include?('--help')

        options = {}
        parse_options(argv, options)
        dispatch_command(command, argv, options)
      rescue Cdd::ValidationError => e
        puts e.message unless e.message.empty?
        1
      end

      # Dispatches the parsed `command` to its handler.
      #
      # @param command [String] CLI subcommand
      # @param argv [Array<String>] remaining arguments
      # @param options [Hash] parsed CLI options
      # @return [Integer] exit code
      def dispatch_command(command, argv, options)
        case command
        when 'mcp' then handle_mcp_command
        when 'sync' then handle_sync_command(options)
        when 'to_openapi' then handle_to_openapi_command(options)
        when 'to_arazzo' then handle_to_arazzo_command(options)
        when 'to_docs_json' then handle_to_docs_json_command(options)
        when 'from_openapi'
          subcommand = argv.shift
          parse_options(argv, options)
          handle_from_openapi_command(subcommand, options)
        when 'from_arazzo'
          subcommand = argv.shift
          parse_options(argv, options)
          handle_from_arazzo_command(subcommand, options)
        when 'serve_json_rpc' then handle_serve_json_rpc_command(options)
        else
          puts "Error: Unknown or incomplete command: #{command}"
          print_help
          raise Cdd::ValidationError, ''
        end
      end

      # Executes the `mcp` stdio JSON-RPC server loop.
      #
      # @return [Integer] exit code `0`
      def handle_mcp_command
        require 'json'
        loop do
          line = $stdin.gets
          break if line.nil?

          process_mcp_line(line)
        end
        0
      end

      # Processes a single JSON-RPC line on the MCP stdio loop.
      #
      # @param line [String] raw input line
      # @return [void]
      def process_mcp_line(line)
        req = JSON.parse(line)
        return if req['id'].nil?

        resp = dispatch_mcp_request(req)
        $stdout.puts JSON.generate(resp)
        $stdout.flush
      rescue JSON::ParserError
        $stdout.puts JSON.generate({ jsonrpc: '2.0', error: { code: -32_700, message: 'Parse error' } })
        $stdout.flush
      end

      # Dispatches a parsed MCP request hash and returns the JSON-RPC response hash.
      #
      # @param req [Hash] parsed JSON-RPC request
      # @return [Hash] JSON-RPC response envelope
      def dispatch_mcp_request(req)
        router = Cdd::McpCoreRouter.new
        resp = { jsonrpc: '2.0', id: req['id'], result: { _meta: {} } }
        case req['method']
        when 'initialize' then resp[:result] = mcp_init_result
        when 'tools/list' then resp[:result] = { tools: MCP_TOOLS }
        when 'tools/call' then resp = handle_mcp_tool_call(req, resp)
        when 'prompts/list', 'prompts/get', 'resources/list', 'resources/read'
          resp[:result] = handle_mcp_prompt_or_resource(req)
        when 'resources/templates/list' then resp[:result] = { resourceTemplates: router.get_resource_templates }
        when 'roots/list' then resp[:result] = { roots: router.get_roots }
        when 'resources/subscribe', 'resources/unsubscribe', 'logging/setLevel', 'ping'
          resp[:result] = {}
        when 'sampling/createMessage'
          resp[:result] = router.sample_message
        when 'completion/complete'
          resp[:result] = router.complete_prompt(nil, nil, nil)
        else
          resp = { jsonrpc: '2.0', id: req['id'], error: { code: -32_601, message: 'Method not found' } }
        end
        resp
      end

      # Returns the MCP `initialize` capabilities payload.
      #
      # @return [Hash] MCP capabilities and serverInfo
      def mcp_init_result
        Cdd::McpCoreRouter.build_init_result('cdd-ruby-mcp', '1.0.0')
      end

      # Handles MCP prompt and resource list/read methods.
      #
      # @param req [Hash] parsed JSON-RPC request
      # @return [Hash] result payload
      def handle_mcp_prompt_or_resource(req)
        case req['method']
        when 'prompts/list'
          arg_def = { name: 'filepath', description: 'Path to source code', required: true }
          { prompts: [{ name: 'generate_docs', description: 'Generate standard documentation', arguments: [arg_def] }] }
        when 'prompts/get'
          fp = (req.dig('params', 'arguments') || {})['filepath']
          msg = { role: 'user', content: { type: 'text', text: "Please generate docs for #{fp}" } }
          { description: 'Generate docs prompt', messages: [msg] }
        when 'resources/list'
          { resources: [{ uri: 'mcp://cdd/docs', name: 'CDD Documentation', mimeType: 'text/markdown' }] }
        else
          ruri = req.dig('params', 'uri')
          { contents: [{ uri: ruri, mimeType: 'text/markdown', text: '# CDD Docs' }] }
        end
      end

      # Handles `tools/call` requests inside the MCP stdio server.
      #
      # @param req [Hash] parsed JSON-RPC request
      # @param resp [Hash] base JSON-RPC response envelope
      # @return [Hash] updated JSON-RPC response envelope
      def handle_mcp_tool_call(req, resp)
        tname = req.dig('params', 'name')
        targs = req.dig('params', 'arguments') || {}
        if tname == 'inspect_schema'
          handle_inspect_schema_tool(req['id'], targs, resp)
        elsif %w[generate_from_openapi generate_to_openapi generate_from_arazzo generate_to_arazzo].include?(tname)
          handle_generate_tool(tname, targs, resp)
        else
          { jsonrpc: '2.0', id: req['id'], error: { code: -32_601, message: 'Method not found' } }
        end
      end

      # Handles the `inspect_schema` MCP tool call.
      #
      # @param req_id [Integer, String] JSON-RPC request ID
      # @param targs [Hash] tool arguments
      # @param resp [Hash] base JSON-RPC response envelope
      # @return [Hash] updated JSON-RPC response envelope
      def handle_inspect_schema_tool(req_id, targs, resp)
        schema = JSON.parse(File.read(targs['filepath']))
        summary = "Schema: #{schema['info']['title']} #{schema['info']['version']}\n"
        summary += "Paths: #{(schema['paths'] || {}).keys.join(', ')}\n"
        summary += "Workflows: #{schema['workflows'].map { |w| w['workflowId'] }.join(', ')}\n" if schema['workflows']
        summary += "Components: #{(schema.dig('components', 'schemas') || {}).keys.join(', ')}\n"
        resp[:result] = { content: [{ type: 'text', text: summary }] }
        resp
      rescue StandardError => e
        log_msg = { jsonrpc: '2.0', method: 'notifications/message',
                    params: { level: 'error', logger: 'mcp-server', data: e.message } }
        $stdout.puts JSON.generate(log_msg)
        { jsonrpc: '2.0', id: req_id, error: { code: -32_603, message: "Internal error: #{e.message}" },
          result: { isError: true, content: [{ type: 'text', text: e.message }] } }
      end

      # Handles `generate_from_*` and `generate_to_*` MCP tool calls.
      #
      # @param tname [String] tool name
      # @param targs [Hash] tool arguments
      # @param resp [Hash] base JSON-RPC response envelope
      # @return [Hash] updated JSON-RPC response envelope
      def handle_generate_tool(tname, targs, resp)
        require 'stringio'
        old_stdout = $stdout
        $stdout = StringIO.new
        begin
          case tname
          when 'generate_from_openapi', 'generate_from_arazzo'
            cmd = tname.sub('generate_', '')
            run([cmd, targs['subcommand'], '-i', targs['input'], '-o', targs['output'] || '.'])
          when 'generate_to_arazzo'
            run(['to_arazzo', '-i', targs['input'], '-o', targs['output'] || 'arazzo.json'])
          else
            run(['to_openapi', '-i', targs['input'], '-o', targs['output'] || 'spec.json'])
          end
        ensure
          $stdout = old_stdout
        end
        resp[:result] = { content: [{ type: 'text', text: 'Generated successfully' }] }
        resp
      end

      # Executes the `sync` subcommand.
      #
      # @param options [Hash] parsed CLI options
      # @return [Integer] exit code
      # @raise [Cdd::ValidationError] when `-i` or `--truth` is missing
      def handle_sync_command(options)
        input = get_arg(options, :i, 'CDD_INPUT')
        truth = get_arg(options, :truth, 'CDD_TRUTH')
        if input.nil? || truth.nil?
          raise Cdd::ValidationError, 'Error: Missing -i <filepath> or --truth <class|activerecord|function>'
        end

        require_relative 'sync'
        Cdd::Sync.sync(input, truth)
        puts 'Synchronization complete.'
        0
      end

      # Resolves a single Ruby file or a directory of Ruby files to parse.
      #
      # @param file [String] file or directory path
      # @return [Array<String>] list of Ruby files
      def resolve_target_ruby_files(file)
        return [file] unless File.directory?(file)

        Dir.glob(File.join(file, '**', '*.rb')).reject do |f|
          f.include?('/spec/') || f.include?('/tests/') || f.include?('/vendor/') ||
            f.include?('/.bundle/') || f.end_with?('_spec.rb') || f.end_with?('_test.rb')
        end
      end

      # Executes the `to_openapi` subcommand.
      #
      # @param options [Hash] parsed CLI options
      # @return [Integer] exit code
      # @raise [Cdd::ValidationError] when `-i` is missing
      def handle_to_openapi_command(options)
        file = get_arg(options, :i, 'CDD_INPUT')
        out = get_arg(options, :o, 'CDD_OUTPUT', 'spec.json')
        raise Cdd::ValidationError, 'Error: Missing -i <filepath> or --input <filepath>' if file.nil?

        result = Cdd::Parser.parse(resolve_target_ruby_files(file))
        write_or_print_output(out, result)
        0
      end

      # Executes the `to_arazzo` subcommand.
      #
      # @param options [Hash] parsed CLI options
      # @return [Integer] exit code
      # @raise [Cdd::ValidationError] when `-i` is missing
      def handle_to_arazzo_command(options)
        file = get_arg(options, :i, 'CDD_INPUT')
        out = get_arg(options, :o, 'CDD_OUTPUT', 'arazzo.json')
        raise Cdd::ValidationError, 'Error: Missing -i <filepath> or --input <filepath>' if file.nil?

        result = Cdd::Parser.parse_to_arazzo(resolve_target_ruby_files(file))
        write_or_print_output(out, result)
        0
      end

      # Executes the `to_docs_json` subcommand.
      #
      # @param options [Hash] parsed CLI options
      # @return [Integer] exit code
      # @raise [Cdd::ValidationError] when `-i` is missing
      def handle_to_docs_json_command(options)
        input = get_arg(options, :i, 'CDD_INPUT')
        out = get_arg(options, :o, 'CDD_OUTPUT', 'docs.json')
        no_imports = get_arg(options, :no_imports, 'CDD_NO_IMPORTS', false)
        no_wrapping = get_arg(options, :no_wrapping, 'CDD_NO_WRAPPING', false)
        raise Cdd::ValidationError, 'Error: Missing -i <filepath>' if input.nil?

        result = Cdd::DocsJson::Emitter.emit(input, no_imports: no_imports, no_wrapping: no_wrapping)
        write_or_print_output(out, result)
        0
      end

      # Writes `result` to `out` (or prints to stdout when `out == '-'`).
      #
      # @param out [String] output destination path or `'-'`
      # @param result [String] generated content
      # @return [void]
      def write_or_print_output(out, result)
        if out == '-'
          puts result
        else
          FileUtils.mkdir_p(File.dirname(out))
          File.write(out, result)
        end
      end

      # Executes the `from_arazzo` subcommand.
      #
      # @param subcommand [String, nil] target subcommand (`to_sdk_cli`, `to_sdk`, `to_server`)
      # @param options [Hash] parsed CLI options
      # @return [Integer] exit code
      def handle_from_arazzo_command(subcommand, options)
        handle_from_openapi_command(subcommand, options, 'from_arazzo')
      end

      # Executes the `from_openapi` or `from_arazzo` subcommand.
      #
      # @param subcommand [String, nil] target subcommand (`to_sdk_cli`, `to_sdk`, `to_server`)
      # @param options [Hash] parsed CLI options
      # @param parent_cmd [String] parent CLI command name
      # @return [Integer] exit code
      # @raise [Cdd::ValidationError] when `-i` / `-d` is missing or `subcommand` is unknown
      def handle_from_openapi_command(subcommand, options, parent_cmd = 'from_openapi')
        input = get_arg(options, :i, 'CDD_INPUT')
        input_dir = get_arg(options, :input_dir, 'CDD_INPUT_DIR')
        unless input || input_dir
          raise Cdd::ValidationError, 'Error: Missing -i <filepath> or -d <dir> or --input-dir <dir>'
        end

        emitter_options = {
          input: input,
          input_dir: input_dir,
          arazzo: get_arg(options, :arazzo, 'CDD_ARAZZO'),
          output: get_arg(options, :o, 'CDD_OUTPUT', Dir.pwd),
          no_github_actions: get_arg(options, :no_github_actions, 'CDD_NO_GITHUB_ACTIONS'),
          no_installable_package: get_arg(options, :no_installable_package, 'CDD_NO_INSTALLABLE_PACKAGE'),
          tests: get_arg(options, :tests, 'CDD_TESTS'),
          mcp: get_arg(options, :mcp, 'CDD_MCP'),
          with_ephemeral: get_arg(options, :with_ephemeral, 'CDD_WITH_EPHEMERAL'),
          with_seed: get_arg(options, :with_seed, 'CDD_WITH_SEED')
        }
        case subcommand
        when 'to_sdk_cli' then puts Cdd::Emitter.emit_sdk_cli(emitter_options)
        when 'to_sdk' then puts Cdd::Emitter.emit_sdk(emitter_options)
        when 'to_server' then puts Cdd::Emitter.emit_server(emitter_options)
        else
          raise Cdd::ValidationError, "Unknown #{parent_cmd} subcommand: #{subcommand}"
        end
        0
      end

      # Executes the `serve_json_rpc` subcommand.
      #
      # @param options [Hash] parsed CLI options
      # @return [Integer] exit code `0`
      def handle_serve_json_rpc_command(options)
        port = get_arg(options, :port, 'CDD_PORT', 8080)
        listen = get_arg(options, :listen, 'CDD_LISTEN', '127.0.0.2')
        Cdd::Server.start(listen, port)
        0
      end
    end
  end
end
