# frozen_string_literal: true

# Entry point for the Cdd Ruby compiler, parser, emitter, and MCP core router.
require 'json'
require 'fileutils'
require 'ripper'

require_relative 'error'
require_relative 'ir'
require_relative 'token_scanner'
require_relative 'scaffolding'

%w[functions classes docstrings routes tests mocks openapi arazzo docs_json server client_sdk
   client_sdk_cli].each do |component|
  require_relative "#{component}/parse"
  require_relative "#{component}/emit"
end

# Core namespace for the CDD Ruby compiler and OpenAPI toolchain.
module Cdd
  # The Parser class reads Ruby files and extracts AST for generating OpenAPI or Arazzo specs.
  class Parser
    # Parses Ruby file(s) into a populated `Cdd::IR` instance.
    #
    # @param filepaths [String, Array<String>] the file path(s) to parse
    # @return [Cdd::IR] populated Intermediate Representation
    def self.parse_to_ir(filepaths)
      ir = Cdd::IR.new
      paths = filepaths.is_a?(Array) ? filepaths : [filepaths]

      paths.each do |filepath|
        next unless File.exist?(filepath)

        code = File.read(filepath)
        tokens = Ripper.lex(code)

        Cdd::Classes::Parser.parse(tokens, ir)
        Cdd::Functions::Parser.parse(tokens, ir)
        Cdd::Docstrings::Parser.parse(tokens, ir)
        Cdd::Routes::Parser.parse(tokens, ir)
        Cdd::Openapi::Parser.parse(tokens, ir)
        Cdd::Mocks::Parser.parse(tokens, ir)
        Cdd::Arazzo::Parser.parse(tokens, ir)
        Cdd::Tests::Parser.parse(tokens, ir, skip_arazzo: true)
        Cdd::ClientSdk::Parser.parse(tokens, ir, skip_arazzo: true)
        Cdd::ClientSdkCli::Parser.parse(tokens, ir, skip_arazzo: true)
      end

      ir
    end

    # Parses Ruby file(s) and returns the OpenAPI representation in JSON.
    #
    # @param filepaths [String, Array<String>] the files to parse
    # @return [String] the OpenAPI representation in JSON
    def self.parse(filepaths)
      JSON.pretty_generate(parse_to_ir(filepaths).openapi_spec)
    end

    # Parses Ruby file(s) and returns the Arazzo 1.1.0 representation in JSON.
    #
    # @param filepaths [String, Array<String>] the files to parse
    # @return [String] the Arazzo 1.1.0 representation in JSON
    def self.parse_to_arazzo(filepaths)
      JSON.pretty_generate(parse_to_ir(filepaths).arazzo_spec)
    end
  end

  # The Emitter class takes an OpenAPI or Arazzo specification and outputs Ruby code.
  class Emitter
    # Reads and parses a JSON specification file, raising `Cdd::ParseError` on invalid JSON.
    #
    # @param filepath [String] path to JSON specification file
    # @return [Object] parsed JSON payload
    # @raise [Cdd::ParseError] when the file does not contain valid JSON
    def self.parse_spec_file(filepath)
      JSON.parse(File.read(filepath))
    rescue JSON::ParserError => e
      raise Cdd::ParseError, "Failed to parse specification #{filepath}: #{e.message}"
    end

    # Validates that a parsed specification is a JSON object (Hash), raising `Cdd::EmitError` otherwise.
    #
    # @param spec [Object] parsed specification payload
    # @return [Hash] validated specification hash
    # @raise [Cdd::EmitError] when `spec` is not a Hash
    def self.validate_spec_hash(spec)
      raise Cdd::EmitError, 'Specification root must be a JSON object (Hash)' unless spec.is_a?(Hash)

      spec
    end

    # Emits Ruby code from an OpenAPI (or Arazzo) definition.
    #
    # @param filepath [String] the OpenAPI or Arazzo JSON file
    # @param original_ruby_filepath [String, nil] optional path to existing ruby file for syncing
    # @return [String] the Ruby source code
    def self.emit(filepath, original_ruby_filepath = nil)
      spec = validate_spec_hash(parse_spec_file(filepath))
      return emit_from_arazzo(filepath, original_ruby_filepath) if spec.key?('arazzo')

      ir = Cdd::IR.new
      if original_ruby_filepath && File.exist?(original_ruby_filepath)
        existing_spec = JSON.parse(Cdd::Parser.parse(original_ruby_filepath))
        ir.openapi_spec = merge_openapi_specs(existing_spec, spec)
      else
        ir.openapi_spec = spec
      end

      ruby_code = "# frozen_string_literal: true\n\n"
      ruby_code += Cdd::Openapi::Emitter.emit(ir)
      ruby_code += Cdd::Classes::Emitter.emit(ir)
      ruby_code += Cdd::Routes::Emitter.emit(ir)
      ruby_code += Cdd::Functions::Emitter.emit(ir)
      ruby_code += Cdd::Tests::Emitter.emit(ir)
      ruby_code += Cdd::Mocks::Emitter.emit(ir)
      ruby_code += Cdd::Arazzo::Emitter.emit(ir)
      ruby_code
    end

    # Emits Ruby workflow orchestrator code from an Arazzo 1.1.0 JSON definition.
    #
    # @param filepath [String] the Arazzo JSON file
    # @param original_ruby_filepath [String, nil] optional path to existing ruby file for syncing
    # @return [String] the Ruby source code
    def self.emit_from_arazzo(filepath, original_ruby_filepath = nil)
      arazzo = parse_spec_file(filepath)
      ir = Cdd::IR.from_arazzo_hash(arazzo)
      if original_ruby_filepath && File.exist?(original_ruby_filepath)
        existing_arazzo = JSON.parse(Cdd::Parser.parse_to_arazzo(original_ruby_filepath))
        ir.arazzo_spec = merge_arazzo_specs(existing_arazzo, arazzo)
      end
      "# frozen_string_literal: true\n\n#{Cdd::Arazzo::Emitter.emit(ir)}"
    end

    # Deep-merges two OpenAPI specifications, giving precedence to target_spec.
    #
    # @param base_spec [Hash] the existing OpenAPI hash parsed from Ruby code
    # @param target_spec [Hash] the incoming OpenAPI hash from JSON
    # @return [Hash] the merged OpenAPI specification
    def self.merge_openapi_specs(base_spec, target_spec)
      merged = base_spec.dup
      target_spec.each do |key, val|
        merged[key] = if merged[key].is_a?(Hash) && val.is_a?(Hash)
                        merge_openapi_specs(merged[key], val)
                      else
                        val
                      end
      end
      merged
    end

    # Deep-merges two Arazzo specifications, giving precedence to target_spec.
    #
    # @param base_spec [Hash] the existing Arazzo hash parsed from Ruby code
    # @param target_spec [Hash] the incoming Arazzo hash from JSON
    # @return [Hash] the merged Arazzo specification
    def self.merge_arazzo_specs(base_spec, target_spec)
      merge_openapi_specs(base_spec, target_spec)
    end

    # Emits an SDK CLI from an OpenAPI or Arazzo definition.
    #
    # @param options [Hash] CLI options containing input/output paths
    # @return [String] the generated CLI source code
    def self.emit_sdk_cli(options)
      Cdd::ClientSdkCli::Emitter.emit_sdk_cli(options)
    end

    # Emits a Server from an OpenAPI or Arazzo definition.
    #
    # @param options [Hash] CLI options containing input/output paths
    # @return [String] the generated server source code
    def self.emit_server(options)
      Cdd::ServerGen::Emitter.emit_server(options)
    end

    # Emits an SDK from an OpenAPI or Arazzo definition.
    #
    # @param options [Hash] CLI options containing input/output paths
    # @return [String] the generated SDK source code
    def self.emit_sdk(options)
      Cdd::ClientSdk::Emitter.emit_sdk(options)
    end

    # Emits an Arazzo-enabled Client SDK from options.
    #
    # @param options [Hash] CLI options containing input/output paths
    # @return [String] the generated SDK source code
    def self.emit_arazzo_sdk(options)
      emit_sdk(options)
    end

    # Emits an Arazzo-enabled Client SDK CLI from options.
    #
    # @param options [Hash] CLI options containing input/output paths
    # @return [String] the generated CLI source code
    def self.emit_arazzo_sdk_cli(options)
      emit_sdk_cli(options)
    end

    # Emits an Arazzo-enabled Server from options.
    #
    # @param options [Hash] CLI options containing input/output paths
    # @return [String] the generated server source code
    def self.emit_arazzo_server(options)
      emit_server(options)
    end
  end

  # Native MCP router and shared protocol builder for Generator SDK / Core
  class McpCoreRouter
    # Default MCP protocol version string.
    PROTOCOL_VERSION = '2024-11-05'

    # Default MCP server capabilities map.
    DEFAULT_CAPABILITIES = {
      tools: { listChanged: true },
      prompts: { listChanged: true },
      logging: {},
      resources: { subscribe: true, listChanged: true },
      experimental: {},
      roots: { listChanged: true },
      sampling: {}
    }.freeze

    # Builds an MCP `initialize` result payload for the given server name and version.
    #
    # @param name [String] server name
    # @param version [String] server version
    # @return [Hash] MCP initialize response payload
    def self.build_init_result(name = 'cdd-ruby-mcp', version = '1.0.0')
      {
        capabilities: DEFAULT_CAPABILITIES,
        serverInfo: { name: name, version: version },
        protocolVersion: PROTOCOL_VERSION
      }
    end

    # Dispatches common MCP protocol methods (`ping`, `logging/setLevel`, `resources/subscribe`,
    # `resources/unsubscribe`, `resources/templates/list`, `roots/list`, `sampling/createMessage`,
    # and `completion/complete`).
    #
    # @param method [String] JSON-RPC method name
    # @return [Hash, nil] result payload hash, or `nil` if `method` is not a common stub method
    def dispatch_common_method(method)
      case method
      when 'resources/templates/list' then { resourceTemplates: get_resource_templates }
      when 'roots/list' then { roots: get_roots }
      when 'resources/subscribe', 'resources/unsubscribe', 'logging/setLevel', 'ping' then {}
      when 'sampling/createMessage' then sample_message
      when 'completion/complete' then complete_prompt(nil, nil, nil)
      end
    end

    # Gets available tools in the generator
    # @return [Array<Hash>] list of tools
    def get_tools
      [
        {
          name: 'parse_ruby_to_openapi',
          description: 'Parse Ruby source code to OpenAPI JSON',
          inputSchema: { type: 'object', properties: { filepath: { type: 'string' } }, required: ['filepath'] }
        },
        {
          name: 'emit_openapi_to_ruby',
          description: 'Emit Ruby source code from OpenAPI JSON',
          inputSchema: { type: 'object', properties: { filepath: { type: 'string' } }, required: ['filepath'] }
        },
        {
          name: 'parse_ruby_to_arazzo',
          description: 'Parse Ruby source code to Arazzo 1.1.0 JSON',
          inputSchema: { type: 'object', properties: { filepath: { type: 'string' } }, required: ['filepath'] }
        },
        {
          name: 'emit_arazzo_to_ruby',
          description: 'Emit Ruby workflow orchestrator source code from Arazzo 1.1.0 JSON',
          inputSchema: { type: 'object', properties: { filepath: { type: 'string' } }, required: ['filepath'] }
        }
      ]
    end

    # Executes an internal MCP tool
    # @param name [String] the tool name
    # @param args [Hash] the tool arguments
    # @return [String] the tool result
    # @raise [Cdd::McpError] when an unknown tool name is provided
    def execute_tool(name, args)
      case name
      when 'parse_ruby_to_openapi' then Cdd::Parser.parse(args['filepath'])
      when 'emit_openapi_to_ruby' then Cdd::Emitter.emit(args['filepath'])
      when 'parse_ruby_to_arazzo' then Cdd::Parser.parse_to_arazzo(args['filepath'])
      when 'emit_arazzo_to_ruby' then Cdd::Emitter.emit_from_arazzo(args['filepath'])
      else
        raise Cdd::McpError, "Unknown tool: #{name}"
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
    # @raise [Cdd::McpError] when the requested URI is not found
    def read_resource(uri)
      raise Cdd::McpError, "Resource not found: #{uri}" unless uri == 'mcp://cdd/ast'

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

    alias complete complete_prompt
  end
end

# Backwards-compatible uppercase alias for Cdd module.
CDD = Cdd
