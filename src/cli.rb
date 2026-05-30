# frozen_string_literal: true

require 'optparse'
require 'json'
require 'fileutils'
require_relative 'cdd'
require_relative 'server'

module CDD
  module CLI
    class << self
      def get_arg(options, key, env_key, default = nil)
        options.key?(key) ? options[key] : (ENV[env_key] || default)
      end

      def print_help
        puts <<~HELP
          cdd-ruby CLI
          Usage:
            cdd-ruby [subcommand] [options]

          Subcommands:
            from_openapi    Generate code from an OpenAPI specification.
            to_openapi      Generate an OpenAPI specification from source code.
            to_docs_json    Generate JSON documentation with code snippets for an OpenAPI specification.
            serve_json_rpc  Expose CLI interface as a JSON-RPC server.

          Options:
            --help, -h      Show this help message
            --version, -v   Show version information

          Examples:
            cdd-ruby serve_json_rpc [--wasi]
            cdd-ruby from_openapi to_sdk_cli -i <spec.json> [-o <target_directory>] [--no-github-actions] [--no-installable-package] [--tests]
            cdd-ruby from_openapi to_sdk -i <spec.json> [-o <target_directory>] [--no-github-actions] [--no-installable-package] [--tests]
            cdd-ruby from_openapi to_server -i <spec.json> [-o <target_directory>]
            cdd-ruby to_openapi -i <path/to/code> [-o <spec.json>]
            cdd-ruby to_docs_json [--no-imports] [--no-wrapping] -i <spec.json> [-o <docs.json>]
        HELP
      end

      # Generate code from an OpenAPI specification.
      def generate_from_openapi(args)
        run(['from_openapi'] + args)
      end

      # Generate an OpenAPI specification from source code.
      def generate_to_openapi(args)
        run(['to_openapi'] + args)
      end

      # Generate JSON documentation with code snippets for an OpenAPI specification.
      def generate_docs_json(args)
        run(['to_docs_json'] + args)
      end

      # Expose CLI interface as a JSON-RPC server.
      def serve_json_rpc(args)
        run(['serve_json_rpc'] + args)
      end

      def run(argv)
        if argv.empty? || argv.include?('-h') || argv.include?('--help')
          print_help
          return 0
        end

        if argv.include?('-v') || argv.include?('--version')
          puts '0.0.1'
          return 0
        end

        command = argv.shift
        options = {}

        while argv.any? && argv[0].start_with?('-')
          arg = argv.shift
          case arg
          when '-i', '--input' then options[:i] = argv.shift
          when '-o', '--output' then options[:o] = argv.shift
          when '--input-dir' then options[:input_dir] = argv.shift
          when '--no-imports' then options[:no_imports] = true
          when '--no-wrapping' then options[:no_wrapping] = true
          when '--no-github-actions' then options[:no_github_actions] = true
          when '--no-installable-package' then options[:no_installable_package] = true
          when '--tests' then options[:tests] = true
          when '-p', '--port' then options[:port] = argv.shift
          when '-l', '--listen' then options[:listen] = argv.shift
          end
        end

        case command
        when 'to_openapi'
          file = get_arg(options, :i, 'CDD_INPUT')
          out = get_arg(options, :o, 'CDD_OUTPUT', 'spec.json')

          if file.nil?
            puts 'Error: Missing -i <filepath> or --input <filepath>'
            return 1
          end

          if File.directory?(file)
            if File.exist?(File.join(file, 'lib', 'client.rb'))
              file = File.join(file, 'lib', 'client.rb')
            else
              files = Dir.glob(File.join(file, '**', '*.rb'))
              file = files.first if files.any?
            end
          end

          result = Cdd::Parser.parse(file)

          if out
            FileUtils.mkdir_p(File.dirname(out))
            File.write(out, result)
          else
            puts result
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
          if out
            FileUtils.mkdir_p(File.dirname(out))
            File.write(out, result)
          else
            puts result
          end
          0

        when 'from_openapi'
          subcommand = argv.shift

          while argv.any? && argv[0].start_with?('-')
            arg = argv.shift
            case arg
            when '-i' then options[:i] = argv.shift
            when '-o' then options[:o] = argv.shift
            when '--input-dir' then options[:input_dir] = argv.shift
            when '--no-github-actions' then options[:no_github_actions] = true
            when '--no-installable-package' then options[:no_installable_package] = true
            when '--tests' then options[:tests] = true
            end
          end

          input = get_arg(options, :i, 'CDD_INPUT')
          input_dir = get_arg(options, :input_dir, 'CDD_INPUT_DIR')
          out = get_arg(options, :o, 'CDD_OUTPUT', Dir.pwd)
          no_gh = get_arg(options, :no_github_actions, 'CDD_NO_GITHUB_ACTIONS')
          no_pkg = get_arg(options, :no_installable_package, 'CDD_NO_INSTALLABLE_PACKAGE')
          tests = get_arg(options, :tests, 'CDD_TESTS')

          unless input || input_dir
            puts 'Error: Missing -i <filepath> or --input-dir <dir>'
            return 1
          end

          emitter_options = {
            input: input,
            input_dir: input_dir,
            output: out,
            no_github_actions: no_gh,
            no_installable_package: no_pkg,
            tests: tests
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
          while argv.any? && argv[0].start_with?('-')
            arg = argv.shift
            case arg
            when '-p', '--port' then options[:port] = argv.shift
            when '-l', '--listen' then options[:listen] = argv.shift
            end
          end

          port = get_arg(options, :port, 'CDD_PORT', '8080')
          listen = get_arg(options, :listen, 'CDD_LISTEN', '127.0.0.1')
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
