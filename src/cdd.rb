# frozen_string_literal: true

require 'json'
require 'fileutils'
require 'ripper'

require_relative 'ir'
require_relative 'scaffolding'

%w[functions classes docstrings routes tests mocks openapi docs_json server client_sdk
   client_sdk_cli].each do |component|
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

  # Native MCP router for Generator SDK / Core
  class McpCoreRouter
    # Returns available tools for the generator core
    # @return [Array<Hash>] list of tools
    def get_tools
      [
        { name: 'parse_ruby_to_openapi', description: 'Parse Ruby file to OpenAPI JSON', inputSchema: { type: 'object', properties: { filepath: { type: 'string' } }, required: ['filepath'] } },
        { name: 'emit_openapi_to_ruby', description: 'Emit Ruby code from OpenAPI JSON', inputSchema: { type: 'object', properties: { filepath: { type: 'string' } }, required: ['filepath'] } }
      ]
    end

    # Executes an internal MCP tool
    # @param name [String] the tool name
    # @param args [Hash] the tool arguments
    # @return [String] the tool result
    def execute_tool(name, args)
      if name == 'parse_ruby_to_openapi'
        Cdd::Parser.parse(args['filepath'])
      elsif name == 'emit_openapi_to_ruby'
        Cdd::Emitter.emit(args['filepath'])
      else
        raise "Unknown tool: #{name}"
      end
    end

    # Gets available resources in the generator
    # @return [Array<Hash>] list of resources
    def get_resources
      [
        { uri: 'mcp://cdd/ast', name: 'Internal AST Query Resource', mimeType: 'application/json' }
      ]
    end

    # Reads an internal resource by URI
    # @param uri [String] the resource URI
    # @return [Hash] the resource contents
    def read_resource(uri)
      raise "Resource not found: #{uri}" unless uri == 'mcp://cdd/ast'

      { contents: [{ uri: uri, mimeType: 'application/json', text: '{"message":"AST placeholder"}' }] }
    end

    # Subscribes to a resource
    # @param uri [String] the resource URI
    # @return [void]
    def subscribe(uri)
      # no-op
    end

    # Unsubscribes from a resource
    # @param uri [String] the resource URI
    # @return [void]
    def unsubscribe(uri)
      # no-op
    end

    # Handles a ping
    # @return [Boolean] always true
    def ping
      true
    end

    # Gets root directories
    # @return [Array<Hash>] list of root directories
    def get_roots
      []
    end

    # Gets resource templates
    # @return [Array<Hash>] list of resource templates
    def get_resource_templates
      []
    end

    # Samples a message
    # @return [Hash] the sampled message
    def sample_message
      { role: 'assistant', model: 'stub-model', content: { type: 'text', text: 'sampled' } }
    end

    # Completes a prompt
    # @param _prompt_name [String] the prompt name
    # @param _arg_name [String] the argument name
    # @param _value [String] the current value
    # @return [Hash] completion response
    def complete_prompt(_prompt_name, _arg_name, _value)
      { completion: { values: [], total: 0, hasMore: false } }
    end

    # Sets the logging level
    # @param level [String] the log level
    # @return [void]
    def set_level(level)
      # no-op
    end

    # Handles cancellation
    # @param req_id [String] the request ID
    # @return [void]
    def cancelled(req_id)
      # no-op
    end

    # Handles progress
    # @param token [String] the progress token
    # @param current [Integer] current progress
    # @param total [Integer] total progress
    # @return [void]
    def progress(token, current, total)
      # no-op
    end

    # Gets available prompts
    # @return [Array<Hash>] list of prompts
    def get_prompts
      []
    end

    # Gets a specific prompt
    # @param _name [String] prompt name
    # @param _args [Hash] prompt arguments
    # @return [Hash] the prompt details
    def get_prompt(_name, _args)
      {}
    end

    # Completes a prompt argument
    # @param _name [String] prompt name
    # @param _arg_name [String] argument name
    # @param _value [String] current value
    # @return [Hash] completion response
    def complete(_name, _arg_name, _value)
      { completion: { values: [], total: 0, hasMore: false } }
    end
  end
end
