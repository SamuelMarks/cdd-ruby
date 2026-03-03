# frozen_string_literal: true

require 'json'
require 'fileutils'
require 'net/http'
require 'ripper'

require_relative 'ir'
require_relative 'scaffolding'

%w[functions classes docstrings routes tests mocks openapi docs_json].each do |component|
  require_relative "#{component}/parse"
  require_relative "#{component}/emit"
end

# Documentation for Cdd
module Cdd
  # The Parser class reads Ruby files and extracts AST for generating OpenAPI.
  class Parser
    # Parses a given file into a Cdd::AST (internal representation).
    # @param filepath [String] the file to parse
    # @return [String] the OpenAPI representation in JSON
    def self.parse(filepath)
      code = File.read(filepath)
      ir = Cdd::IR.new
      tokens = Ripper.lex(code)
      
      # Modularity: Pass tokens through the parsers
      # Each parser extracts relevant context and mutates/populates the IR
      Cdd::Classes::Parser.parse(tokens, ir)
      Cdd::Functions::Parser.parse(tokens, ir)
      Cdd::Docstrings::Parser.parse(tokens, ir)
      Cdd::Routes::Parser.parse(tokens, ir)
      Cdd::Openapi::Parser.parse(tokens, ir)
      Cdd::Mocks::Parser.parse(tokens, ir)
      Cdd::Tests::Parser.parse(tokens, ir)
      
      JSON.pretty_generate(ir.openapi_spec)
    end
  end

  # The Emitter class takes an OpenAPI specification and outputs Ruby code.
  class Emitter
    # Emits Ruby code from an OpenAPI definition.
    # @param filepath [String] the OpenAPI JSON file
    # @param original_ruby_filepath [String, nil] optional path to existing ruby file for syncing
    # @return [String] the Ruby source code
    def self.emit(filepath, original_ruby_filepath = nil)
      openapi = JSON.parse(File.read(filepath))
      ir = Cdd::IR.new
      ir.openapi_spec = openapi
      
      if original_ruby_filepath && File.exist?(original_ruby_filepath)
        # Attempt an in-place edit where we reconstruct the ruby AST and merge
        # This is the "editing bidirectional syncing" requirement.
        # For full implementation, one would write a comprehensive syntax-tree rewriter.
        # Here we provide the stub logic integrating with Ripper.
        # _original_tokens = Ripper.lex(File.read(original_ruby_filepath))
        # _merge_logic_goes_here(ir, _original_tokens)
      end
      
      # Reverse: generate Ruby code using Emitters
      ruby_code = "# frozen_string_literal: true\n\n"
      
      # Modularity: each emitter generates specific parts
      ruby_code += Cdd::Openapi::Emitter.emit(ir)
      ruby_code += Cdd::Classes::Emitter.emit(ir)
            ruby_code += Cdd::Routes::Emitter.emit(ir)
      ruby_code += Cdd::Functions::Emitter.emit(ir)
      ruby_code += Cdd::Tests::Emitter.emit(ir)
      ruby_code += Cdd::Mocks::Emitter.emit(ir)
      
      ruby_code
    end

    # Emits an SDK CLI from an OpenAPI definition
    # @param options [Hash] CLI options containing input/output paths
    # @return [String] the generated CLI source code
    def self.emit_sdk_cli(options)
      input_file = options[:input] || Dir.glob("#{options[:input_dir]}/*.json").first
      openapi = JSON.parse(File.read(input_file))
      
      ruby_code = "# frozen_string_literal: true\n\n"
      ruby_code += "# Auto-generated SDK CLI for #{openapi.dig('info', 'title') || 'API'}\n\n"
      ruby_code += "require 'json'\nrequire 'net/http'\n\n"
require 'fileutils'
      ruby_code += "def print_help\n"
      ruby_code += "  puts 'Usage: sdk_cli [command] [options]'\n"
      
      if openapi['paths']
        openapi['paths'].each do |path, methods|
          methods.each do |method, details|
            operation_id = details['operationId'] || "#{method}_#{path.gsub(/[^a-zA-Z0-9]/, '_')}"
            ruby_code += "  puts '  #{operation_id}'\n"
          end
        end
      end
      ruby_code += "end\n\n"
      
      ruby_code += "if ARGV.empty? || ARGV.include?('-h') || ARGV.include?('--help')\n"
      ruby_code += "  print_help\n  exit\nend\n\n"
      
      ruby_code += "command = ARGV.shift\ncase command\n"
      
      if openapi['paths']
        openapi['paths'].each do |path, methods|
          methods.each do |method, details|
            operation_id = details['operationId'] || "#{method}_#{path.gsub(/[^a-zA-Z0-9]/, '_')}"
            ruby_code += "when '#{operation_id}'\n"
            ruby_code += "  puts 'Calling #{method.upcase} #{path}'\n"
            # Add basic stub for making request
          end
        end
      end
      
      ruby_code += "else\n  puts \"Unknown command: \#{command}\"\nend\n"
      
      # Write to output directory if needed
      FileUtils.mkdir_p(options[:output]) if options[:output]
      if options[:output]
        Cdd::Scaffolding.generate(options, 'sdk_cli')
        File.write(File.join(options[:output], 'sdk_cli.rb'), ruby_code)
      end
      
      ruby_code
    end

    # Emits a Server from an OpenAPI definition
    # @param options [Hash] CLI options containing input/output paths
    # @return [String] the generated server source code
    def self.emit_server(options)
      input_file = options[:input] || Dir.glob("#{options[:input_dir]}/*.json").first
      openapi = JSON.parse(File.read(input_file))
      
      ruby_code = "# frozen_string_literal: true\n\n"
      ruby_code += "require 'sinatra'\nrequire 'json'\nrequire 'active_record'\n\n"
require 'fileutils'
      
      if openapi['paths']
        openapi['paths'].each do |path, methods|
          sinatra_path = path.gsub(/\{([^}]+)\}/, ':\1')
          methods.each do |method, details|
            ruby_code += "#{method.downcase} '#{sinatra_path}' do\n"
            ruby_code += "  content_type :json\n"
            ruby_code += "  { message: 'Not implemented' }.to_json\n"
            ruby_code += "end\n\n"
          end
        end
      end
      
      FileUtils.mkdir_p(options[:output]) if options[:output]
      if options[:output]
        Cdd::Scaffolding.generate(options, 'server')
        File.write(File.join(options[:output], 'server.rb'), ruby_code)
      end
      
      ruby_code
    end
  end
end
