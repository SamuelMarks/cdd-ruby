# frozen_string_literal: true

require 'json'
require 'fileutils'
require 'net/http'
require 'ripper'

require_relative 'ir'
require_relative 'scaffolding'

%w[functions classes docstrings routes tests mocks openapi docs_json server client_sdk client_sdk_cli].each do |component|
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
      
      # Also parse generated files (bidirectional syncing)
      Cdd::ServerGen::Parser.parse(tokens, ir)
      Cdd::ClientSdk::Parser.parse(tokens, ir)
      Cdd::ClientSdkCli::Parser.parse(tokens, ir)
      
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
      Cdd::ClientSdkCli::Emitter.emit_sdk_cli(options)
    end

    # Emits a Server from an OpenAPI definition
    # @param options [Hash] CLI options containing input/output paths
    # @return [String] the generated server source code
    def self.emit_server(options)
      Cdd::ServerGen::Emitter.emit_server(options)
    end
    
    # Emits an SDK from an OpenAPI definition
    def self.emit_sdk(options)
      Cdd::ClientSdk::Emitter.emit_sdk(options)
    end
  end
end
